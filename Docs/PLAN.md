# Bug Fix & Cleanup Plan

## Bug 1: Credit Amount Wrong (~5000 instead of ~500)

**Root cause**: Rolling 7-day credit window is misaligned with the weekly
`daysLeft` countdown. Credit never resets — it's a perpetual rolling accumulation.
For a consistent dieter eating ~600 below baseBudget daily, credit = 600 × 7 = 4200.

**Fix**: Switch to **week-aligned credit**. Credit window runs from
`today.previous(firstWeekday)` to yesterday, not rolling 7 days.

```
credit = baseBudget × daysElapsedThisWeek − thisWeekIntake
```

This gives a clean weekly reset on `firstWeekday`. A user who ate 500 under
budget for 4 days has credit = 2000, spread over 3 remaining days — matching
the intended mental model.

**Files**:
- `Shared/Services/Analytics/BudgetService.swift` — change `credit` to accept
  week-aligned intakes instead of rolling intakes
- `Shared/Services/HealthData/BudgetDataService.swift` — change rolling fetch to
  use `today.previous(firstWeekday)` → `yesterday` date range instead of
  `today - 7 days` → `yesterday`

**No-goal behavior**: Leave as-is. Credit tracks deviation from baseBudget
(= maintenance when no goal set). Valid use case: "end each week with 500 credit."

---

## Bug 2: Low Confidence & Only 7 Data Points

**Root cause**: `BudgetService.calories` (an `IntakeAnalyticsService`) is fed only
7 days of data but uses `windowDays = 28` and `minDataPoints = 14` for confidence.
`spanFactor = 7/28 = 0.25`, so confidence can never exceed ~25%.

**Fix**: Remove `BudgetService.calories` entirely. Its display metrics (7-Day
Average, Today's Intake, Long-Term Average) should come from
`BudgetService.weight.calories` (the maintenance service's intake analytics,
which has 28 days of data). This eliminates the redundant 7-day
`IntakeAnalyticsService` and the redundant `calorieData` fetch.

**Changes**:
- `BudgetService` — remove `calories: IntakeAnalyticsService` property. Move
  `currentIntake`, `remaining` to reference `weight.calories` instead.
- `BudgetDataService` — remove the `calorieData` fetch (it was identical to
  `rollingCalorieData` anyway). Remove `currentCalorieData` duplication — pass
  it via `weight.calories.currentIntakes`.
- `OverviewComponent` — update all references from `.calories.X` to `.weight.calories.X`.
  Remove "Calorie Data Confidence" row (use weight confidence only, since that's
  what `isValid` checks). Keep 7-Day Average and Long-Term Average (they come from
  `weight.calories` now, with 28d data).
- `BudgetComponent` — update `currentIntake` references.
- Widget files — update references.

---

## Bug 3: Background Crashes

### 3a. `fatalError` in release builds (CRITICAL)

**Root cause**: `App.swift:20-22` — `fatalError()` in release builds when
`AppSchema.createContainer()` throws. The in-memory fallback code below it is
dead code since `fatalError` never returns. SQLite contention with widget extension
during background cold-launch triggers this consistently.

**Fix**: Remove `fatalError`. Let the existing recovery path execute: try erase +
recreate, then fall back to in-memory container. Add conditional compilation so all
build configs use the same recovery path.

**File**: `App/App.swift` lines 20-22

### 3b. Observer retry kills sibling observers

**Root cause**: `HealthKitObservers.swift:58-67` — retry calls
`startObserving(for: widgetKind, dataTypes: [dataType], ...)` which calls
`stopObserving(for: widgetKind)` first, removing ALL observers with that prefix.

**Fix**: Create a `restartSingleObserver(...)` method that stops only the specific
observer key and re-registers just that one query.

**File**: `Shared/Services/HealthKit/HealthKitObservers.swift`

### 3c. Observer callback fan-out

**Root cause**: 7 separate `HKObserverQuery` instances all fire the same `onUpdate`
closure independently. One food log triggers up to 7 simultaneous Tasks, each
calling widget reloads.

**Fix**: Add debounce (1.5s) in `AppHealthKitObserver.onHealthKitDataChanged`.
Coalesce rapid-fire callbacks into a single refresh + widget reload.

**File**: `Shared/Services/AppHealthKitObserver.swift`

### 3d. `fetchStatistics` can hang forever

**Root cause**: `withCheckedContinuation` in `HealthKitStatistics.swift:61` has no
timeout. If HealthKit hangs, the budget pipeline freezes permanently.

**Fix**: Wrap in task group with 15-second timeout. On timeout, stop the query and
return empty results.

**File**: `Shared/Services/HealthKit/HealthKitStatistics.swift`

### 3e. Redundant `enableBackgroundDelivery`

Two call sites: `HealthKitService.init()` and per-observer in
`HealthKitObservers.swift`. Remove the per-observer call.

**Files**: `Shared/Services/HealthKit/HealthKitObservers.swift`,
`Shared/Services/HealthKit/HealthKitService.swift`

---

## Bug 4: `Date()` in Codable Analytics Structs

**Root cause**: `windowIntakes`, `windowWeights`, `windowBodyFat`, and
`computeWeightedSlope` all use `Date()` in computed properties. When widgets
deserialize cached `BudgetService`, the window shifts forward, altering all values.

**Fix**: Add a stored `referenceDate` property (set at construction time) to both
`IntakeAnalyticsService` and `MaintenanceService`. Replace all `Date()` calls with
`referenceDate`.

**Files**:
- `Shared/Services/Analytics/IntakeAnalyticsService.swift` (line 58)
- `Shared/Services/Analytics/MaintenanceService.swift` (lines 100, 107, 222)

---

## Additional Fixes

### Credit label says "kcal/day" — it's total kcal
**File**: `OverviewComponent.swift` line 184 — change `subtitle: "kcal/day"` to
`subtitle: "kcal"`

### No date predicate on statistics queries (performance)
**File**: `HealthKitStatistics.swift` line 65 — pass
`HKQuery.predicateForSamples(withStart: from, end: to)` as
`quantitySamplePredicate` instead of `nil`.

### Calendar inconsistency
**File**: `HealthKitStatistics.swift` lines 31, 59 — change `Calendar.current` to
`.autoupdatingCurrent`.

### Force unwraps
- `HealthKitStatistics.swift` line 41 — `floored(...)!` → guard let
- `StatisticsService.swift` lines 105, 117 — `weekday!` → guard let

### Dead code
- `OverviewComponent.swift` lines 415-502 — unused `proteinSection`,
  `carbsSection`, `fatSection` `@ViewBuilder` properties.

### App observer covers only 28 days vs budget's 730 days
- `AppHealthKitObserver.swift` line 49 — change to cover the widest historical
  stage (730 days) so historical data imports trigger refreshes.

### Widget fallback prefers invalid over cached
- `BudgetWidget.swift` line 103 — change `budgetService ?? cached` to prefer
  cached when `budgetService` exists but `!isValid`.

### Overview blocks on macros for calories focus
- `OverviewComponent.swift` lines 61-66 — when `focus == .calories`, render
  immediately after budget loads, don't wait for macros.

---

## Overview Page: Add Algorithm Internals

**Problem**: Many intermediate values in the maintenance pipeline are invisible,
making it impossible to verify the math is working correctly. The user can see
Maintenance = 3100 but can't tell if that's because ρ is wrong, blending is
pulling toward a bad fallback, or the slope is being clamped.

**Fix**: Add an "Algorithm Details" drill-in section to the calories overview
page. This surfaces the full maintenance derivation chain.

**New rows (under a drill-in "Algorithm Details" section):**

| Row | Value | Source Property | Unit |
|-----|-------|-----------------|------|
| **ρ (Energy Density)** | Forbes model output or default | `weight.rho` | kcal/kg |
| **Weight Slope (Raw)** | Before clamping to [-1, +0.75] | `weight.rawWeightSlope` | kg/week |
| **Weight Slope (Clamped)** | After physiological bounds | `weight.weightSlope` | kg/week |
| **Slope Clamped** | Whether clamping is active | `rawWeightSlope != weightSlope` | yes/no indicator |
| **Energy Imbalance** | $\hat{s} \times \rho / 7$ | `weight.blendedSlope * weight.rho / 7` | kcal/day |
| **Blended Intake** | Intake EWMA dampened toward fallback | `weight.blendedIntake` | kcal/day |
| **Raw Maintenance** | Before confidence blending | `weight.rawMaintenance` | kcal/day |
| **Fallback Maintenance** | What the system blends toward | `weight.fallbackMaintenance` | kcal/day |
| **Fallback Source** | Which stage produced the fallback | new property on `BudgetDataService` | text (e.g. "180d personal", "baseline") |
| **Final Maintenance** | After all blending | `weight.maintenance` | kcal/day |

**Existing rows to update:**
- "Weight Trend" already shows clamped slope — add "(clamped)" suffix when active
- Remove "Calorie Data Confidence" (per Bug 2 fix)

**Implementation notes:**
- Make `blendedIntake`, `blendedSlope` public on `MaintenanceService` (currently private)
- Add `fallbackSource: String` stored property to `BudgetDataService` (set during
  `computeHistoricalMaintenance` — "180d personal", "365d personal", "730d personal",
  or "baseline 2200")
- The drill-in keeps the main overview clean while giving full diagnostic power

**Files**:
- `Shared/Services/Analytics/MaintenanceService.swift` — make internals public
- `Shared/Services/HealthData/BudgetDataService.swift` — add `fallbackSource`
- `Shared/Views/Analytics/OverviewComponent.swift` — add drill-in section

---

## Code Organization Goal

Move all formulas into dedicated files:
- **`BudgetService.swift`** — credit formula, budget assembly (pure math, no HealthKit)
- **`MaintenanceService.swift`** — maintenance, regression, Forbes model (pure math)
- **`IntakeAnalyticsService.swift`** — EWMA, confidence (shared math helper)
- **`StatisticsService.swift`** — EWMA implementation, date helpers

Keep `BudgetDataService.swift` as the orchestrator that fetches data from HealthKit
and constructs the analytics services. No math in the data service.

---

## Verification

- `swift build` after each change
- Credit with week-aligned window: eating 500 under budget for 4 days = credit 2000
- Credit resets on firstWeekday
- Background: app survives container failure with in-memory fallback
- Observer retry: one type failing doesn't kill others
- Widget: shows cached valid data when fresh data is invalid
