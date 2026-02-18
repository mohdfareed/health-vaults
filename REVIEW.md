# HealthVaults Project Review

## Current State (Feb 16, 2026)

### Architecture Overview

**Data Flow:**
- **HealthKit** → Source of truth for health metrics
- **SwiftData** → Local store for app-created entries, synced to HealthKit
- **AppStorage** → User preferences (units, theme, goals)
- **DataQuery** → Property wrapper for paginated HealthKit queries
- **HealthDataNotifications** → Observable service for data change events

### Key Components

| Component | Purpose |
|-----------|---------|
| `DataQuery` | Paginated HealthKit query with `reload()`, `loadNextPage()`, `removeItem()` |
| `HealthDataNotifications` | Notifies views when HealthKit data changes |
| `.refreshOnHealthDataChange` | View modifier that triggers action on data change |
| `RecordList` | Uses `DataQuery` + `refreshOnHealthDataChange` for reactive updates |
| `BudgetDataService` | Calculates daily budget from maintenance + goal + credit |

### Budget System

**Core Formula:**
```
Today's Budget = Maintenance + Goal + Credit Adjustment
```

**Key Concepts:**
- **Maintenance**: Calories you burn per day (learned from weight trends)
- **Credit**: Over/under from past 7 days, spread to next week reset
- **Credit Adjustment**: `credit / daysLeft`, capped at ±500 kcal/day

### Widget Updates
- `AppHealthKitObserver` - listens to HealthKit changes, reloads widgets
- `AppLocale` bindings - reload on unit/firstDayOfWeek change
- `GoalsView` - reload on goals save
- `WidgetDataCache` - caches last-known-good data in SharedDefaults for fallback

---

## Bug Fixes (Feb 16, 2026)

### Background Crash Fix

**Root cause**: Infinite observer retry loop in `HealthKitObservers.swift`. When
`HKObserverQuery` errored, it retried every 5 seconds forever with no cap, keeping
the app awake until the iOS watchdog killed it.

**Fixes applied:**
1. **Capped retries at 3** with exponential backoff (5s → 15s → 45s). Retry counts
   stored per observer key in `observerRetryCounts` dictionary.
2. **Serialized `activeObservers` access** using existing `observerQueue` — all
   reads/writes now go through `observerQueue.sync {}` to prevent data races.
3. **Stored NotificationCenter observer token** — `unitObserverToken` property
   prevents leaked observer; closure uses `[weak self]`.

**Files changed:**
- `Shared/Services/HealthKit/HealthKitService.swift` — added retry state, token property
- `Shared/Services/HealthKit/HealthKitObservers.swift` — retry cap, queue serialization
- `Shared/Services/HealthKit/HealthKitUnits.swift` — stored observer token, `[weak self]`

### Widget Reset Fix

**Root cause**: No cached fallback existed — when widget timeline generation failed
or produced invalid data, it showed baseline + zeroes. Additionally, a new
ModelContainer was created per timeline generation causing SQLite contention.

**Fixes applied:**
1. **Widget data cache** — `WidgetDataCache` enum in `WidgetsBundle.swift` saves
   last-known-good `BudgetService` and `MacrosAnalyticsService` as JSON in
   SharedDefaults. Both service types made `Codable`. Widget falls back to cached
   data when fresh HealthKit data is invalid/empty.
2. **Static ModelContainer cache** — `WidgetsSettings.cachedContainer` avoids
   creating a new SQLite connection on every timeline generation.
3. **Analytics types made Codable** — `IntakeAnalyticsService`, `MaintenanceService`,
   `BudgetService`, `MacrosAnalyticsService` all gained `Codable` conformance.

**Files changed:**
- `Widgets/WidgetsBundle.swift` — `WidgetDataCache`, cached container
- `Widgets/BudgetWidget.swift` — cache save/load
- `Widgets/MacrosWidget.swift` — cache save/load
- `Shared/Services/Analytics/*.swift` — `Codable` conformance

---

## Codebase Cleanup (Feb 16, 2026)

Comprehensive dead code removal:

**Removed:**
- `View.transform()` — unused extension (CoreService.swift)
- `AppError.runtimeError` case — no callers (Core.swift)
- `Query.Settings` typealias — unused (SettingsService.swift)
- `UnitMass.standardDrink` — never referenced (Units.swift)
- `UnitDuration.weeks` — never referenced (Units.swift)
- `stopAllObservers()` — never called (HealthKitObservers.swift)
- `HKWorkoutBuilder` extension — dead code (HealthKitCore.swift)
- `fetchSamples(for: HealthKitDataType)` wrapper — unused (HealthKitQueries.swift)
- `Sequence.points()` overloads, `[Date: Double].points` — unused (StatisticsService.swift)
- Stale TODOs, `DisplayAlpha`, `MaxDailyAdjustment` — unused (Config.swift)
- All commented-out `activeCalories`/`basalCalories` cases across HealthKit files

**Fixed:**
- `fetchDietarySamples` / `fetchAlcoholSamples` — bug where `finalPredicate` was built but original `predicate` was passed instead
- `observerKey` visibility — changed from `public` to `internal` (only used internally)
- Collapsed duplicate `sampleType`/`quantityType` in HealthKitCore (sampleType now delegates)

**Removed unused imports:**
- `SwiftUI` from HealthKitCore, HealthKitQueries, HealthKitObservers, Authentication
- `SwiftData`/`SwiftUI`/`WidgetKit` from all analytics services
- `SwiftData` from SettingsService, `HealthKit` from Weight.swift

---

## Key Patterns

- Use `.task` with `hasLoaded` guard for one-time loads
- Use `.refreshOnHealthDataChange` for reactive data updates
- Use `DataQuery.removeItem()` for optimistic deletes
- Use `hasAppeared` state to control animations on initial load
- Observer retries: max 3, exponential backoff, then give up

## Version
- App version: 1.4 (build 1)

---

## Current Session (Feb 17, 2026)

### Objective
- Run a user-facing copy usability review focused on permission language and misleading phrasing.

### Decisions
- Updated both Health read and write usage descriptions to accurate, user-centric language.
- Removed `NSHealthClinicalHealthRecordsShareUsageDescription` from build settings because no clinical-record APIs are used.
- Kept scope focused on misleading/awkward text only (no feature or flow changes).

### Notes
- HealthKit usage strings are defined via Xcode build settings in [HealthVaults.xcodeproj/project.pbxproj](HealthVaults.xcodeproj/project.pbxproj#L425-L649).
- Supported HealthKit types are enumerated in [Shared/Services/HealthKit/HealthKitCore.swift](Shared/Services/HealthKit/HealthKitCore.swift#L7-L29).
- App-wide HealthKit observation uses those types in [Shared/Services/AppHealthKitObserver.swift](Shared/Services/AppHealthKitObserver.swift#L33-L72).
- Body fat % read is queried directly in [Shared/Services/HealthData/BudgetDataService.swift](Shared/Services/HealthData/BudgetDataService.swift#L182-L220).
- HealthKit authorization (read/write sets) is defined in [Shared/Services/HealthKit/Authentication.swift](Shared/Services/HealthKit/Authentication.swift#L12-L35).

### Updated Copy
- Permission strings in [HealthVaults.xcodeproj/project.pbxproj](HealthVaults.xcodeproj/project.pbxproj#L425-L649)
- About text in [Shared/Views/AboutView.swift](Shared/Views/AboutView.swift#L20-L38)
- Settings health footer in [App/SettingsView.swift](App/SettingsView.swift#L43-L49)
- Widget and list phrasing in [Widgets/MacrosWidget.swift](Widgets/MacrosWidget.swift#L22-L49), [Widgets/BudgetWidget.swift](Widgets/BudgetWidget.swift#L46-L49), and [Shared/Views/Records/RecordList.swift](Shared/Views/Records/RecordList.swift#L79-L83)

### Copy Rationale
- Permission text should explain user benefit and Apple Health data flow, not only technical read/write verbs.
- Read copy now clarifies the app can use data aggregated from other apps through Apple Health.
- Write copy now clarifies entries created in HealthVaults become available to Apple Health and other permitted apps.

---

## Implementation Session (Feb 17, 2026) — UI TODO Fixes

### Objective
- Fix permissions status indicator behavior, precision-sensitive computed actions, settings ordering, dashboard budget footnote copy, keyboard toolbar alignment, and README TODO tracking.

### Decisions Applied
- Health permissions indicator uses tri-state semantics: no access (red), partial access (yellow), full access (green).
- Authorization aggregation now evaluates all required HealthKit types including body fat percentage read access.
- Computed-value visibility now compares formatted display values (precision-aware) instead of `Double.ulpOfOne`.
- Dashboard calorie footnote remains under the dashboard card (not inside widgets) and includes exact days remaining.
- Keyboard toolbar Done button is left-most in shared numeric input toolbars.
- Settings section order is Goals first, then General.

### Files Updated
- `Shared/Services/HealthKit/Authentication.swift`
- `Shared/Views/AboutView.swift`
- `Shared/Views/Records/RecordRow.swift`
- `Shared/Views/Components/MeasurementField.swift`
- `Shared/Views/Analytics/BudgetComponent.swift`
- `App/SettingsView.swift`
- `README.md`

### Follow-up Fixes (same session)
- Permissions indicator now animates status text/symbol changes with SwiftUI content transitions.
- Authorization aggregate now checks writable HealthKit types only for tri-state status, fixing the missing green "all authorized" state.
- Record keyboard toolbar now places Done first, before Invert/computed controls.
- Dashboard calorie footnote visibility is now explicitly driven by `BudgetComponent(showDashboardFootnote:)` and enabled from `DashboardView`.
- Computed value indicator keeps numeric-text digit animation and now includes fade transition on label content changes.
- Floating global add (`+`) menu now hides while keyboard is visible to avoid large upward displacement caused by keyboard + accessory toolbar safe-area changes.
- Dashboard calorie footnote copy updated to concise formula wording with explicit divisor and days-remaining explanation.
- Goals page segmented control moved outside the form rows (top bar-style container) to remove extra white cell background and keep native separation between Calories and Macros.
- Overview page redesigned as a screenshot-friendly diagnostic report: Snapshot, Calorie Inputs, Maintenance Model, Budget Math, and inline Macros summary sections.
- Removed macro drill-down dependency in Overview detail flow so one screenshot can capture most algorithm inputs/outputs.
- Copy updated to make formulas and model behavior easier to understand for non-technical users while preserving diagnostic value.
- Dashboard overview entry removed; calories and macros cards now navigate directly to focused overview pages (`Calorie Overview` / `Macros Overview`).
- Goals header adjusted to a standard inline-title + in-form segmented control layout to avoid oversized top inset and hidden title.
- Added dashboard-only calibration indicator under the calories card content using periodic swing animation (non-continuous), replacing prior continuous spinner behavior.

---

## UI Changes (Feb 16, 2026)

### Goals Page
- `GoalView` moved from inline Form sections to a dedicated page via NavigationLink
- Accessible from Settings via "Goals" row with target icon
- Contains same sections: Calorie Goal (maintenance + adjustment) and Macros Breakdown

### Dashboard Budget Note
- `DashboardCard` now supports an optional `footer` string parameter
- Calories card shows footer: "Budget = maintenance + goal adjustment + weekly credit ÷ days remaining"

### Widget "Remaining" Label
- `ValueView` now supports an optional `label` parameter to override the unit symbol
- `CalorieContent` in `BudgetComponent` uses `label: "Remaining"` instead of showing "kcal"
- Applies to both dashboard and medium widget budget displays

### Staleness Indicator — Removed
- `StalenessIndicator` view, timestamp keys/methods, and `cachedAt` properties removed
- Feature was prototyped but dropped before release
