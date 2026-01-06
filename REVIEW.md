# HealthVaults Project Review

## Bug Fixes Applied (Jan 5, 2026)

### 1. Calorie Counting Bug - FIXED
**Problem**: `HKStatisticsCollectionQuery` returned 1,200 kcal while raw samples totaled 2,350 kcal.
**Root Cause**: Statistics query may not count samples inside `HKCorrelation` (food correlations).
**Solution**: Sum raw samples directly for current day's intake instead of using statistics.

### 2. Weight Slope Calculation - FIXED
**Problem**: Weight change showed 0.88 kg/week instead of expected 3.5 kg/week (0.5 kg in 1 day).
**Root Cause**: EWMA was applied to weight series BEFORE linear regression, dampening recent changes.
**Solution**: Use raw weights for linear regression (regression already handles noise).

### 3. Weight Analytics Edge Cases - FIXED
**Problem**: With only 2 data points over 2 days (0.5kg difference), maintenance calculated as -869 kcal.
**Root Cause**: Linear regression with sparse data is unreliable; day-to-day fluctuations dominate.
**Solution**: Unified confidence system across all analytics services:

**Confidence Application:**
| Service | Confidence Effect |
|---------|-------------------|
| `WeightAnalyticsService.weightSlope` | Blended toward 0 kg/wk baseline, then clamped |
| `WeightAnalyticsService.maintenance` | Blended toward 2000 kcal/day baseline |
| `BudgetService.credit` | Gated: returns nil if `weight.isValid` is false |

**Blending formula:** `value = raw × confidence + baseline × (1 - confidence)`

**Config Constants:**
| Constant | Value | Purpose |
|----------|-------|---------|
| `MinWeightSpanDays` | 14 | Weight data span for valid regression |
| `MinWeightDataPoints` | 5 | Weight measurements for valid regression |
| `MinCalorieSpanDays` | 7 | Calorie data span for valid EWMA |
| `MinCalorieDataPoints` | 4 | Calorie measurements for valid EWMA |
| `MaxWeightLossPerWeek` | 1.0 kg | Physiological clamp |
| `MaxWeightGainPerWeek` | 0.5 kg | Physiological clamp |
| `BaselineMaintenance` | 2000 kcal | Default when data insufficient |

### EWMA Usage Guidelines
| Data | Use EWMA? | Reason |
|------|-----------|--------|
| Historical calorie intake | ✅ YES | Smooths daily variation for "typical" intake |
| Today's intake | ❌ NO | Show actual sum from raw samples |
| Weight for slope calc | ❌ NO | Linear regression handles noise |
| Maintenance calculation | ✅ YES | Uses smoothed intake + raw weight slope |

---

## Architecture Refactor Plan v1.0

### Guiding Principles

1. **One change at a time** - Each step is a single, focused change
2. **Always buildable** - Code compiles and runs after every step
3. **Review gates** - User reviews and approves before proceeding
4. **No big rewrites** - Evolve, don't replace

---

## Phase 1: Observer Consolidation

**Goal**: Merge 3 observer mechanisms into 1

**Current State**:
- `AppHealthKitObserver` (actor singleton) - widget refresh
- `HealthDataNotifications` (Observable) - view reactivity
- `HealthKitObservers` extension - query management

**Target State**:
- Single `HealthKitObserver` that does all three jobs

### Step 1.1: Audit observer usage
- [x] Map all call sites for each observer mechanism
- [x] Document what each actually does
- **Review gate**: ✅ Confirmed understanding

### Step 1.2: Merge HealthDataNotifications into AppHealthKitObserver
- [x] Move notification timestamps into HealthKitObserver
- [x] Update `.refreshOnHealthDataChange` to use consolidated observer
- [x] Remove HealthDataNotifications.swift
- [x] Remove AppHealthKitObserver.swift
- **Review gate**: Test view refresh still works

### Step 1.3: Inline HealthKitObservers extension
- [ ] Move observer query management into main HealthKitObserver
- [ ] Remove the extension file
- **Review gate**: Test widget updates still work

### Step 1.4: Rename and clean up
- [ ] Rename to clear, final name
- [ ] Clean up public API surface
- **Review gate**: Final observer API review

---

## Phase 2: HealthKit Layer Consolidation

**Goal**: 7 files → 3 files

**Current Files**:
```
HealthKitService.swift      (66 lines)  - singleton init
HealthKitDataTypes.swift    (100 lines) - type definitions
HealthKitSamples.swift      (185 lines) - sample queries
HealthKitStatistics.swift   (133 lines) - statistics queries
HealthKitObservers.swift    (107 lines) - observer queries (done in Phase 1)
HealthKitAuthorization.swift (67 lines) - auth handling
HealthKitUnits.swift        (129 lines) - unit mapping
```

**Target Files**:
```
HealthKitService.swift      - core service + auth
HealthKitQueries.swift      - all query methods (samples + statistics)
HealthKitObserver.swift     - observation (from Phase 1)
```

### Step 2.1: Merge Authorization into Service
- [ ] Move auth methods into main HealthKitService.swift
- [ ] Delete HealthKitAuthorization.swift
- **Review gate**: Auth still works

### Step 2.2: Merge DataTypes into Service
- [ ] Move HealthKitDataType enum into HealthKitService.swift
- [ ] Delete HealthKitDataTypes.swift
- **Review gate**: Build passes

### Step 2.3: Merge Units into Service
- [ ] Move unit mappings into HealthKitService.swift
- [ ] Consider simplifying to a dictionary
- [ ] Delete HealthKitUnits.swift
- **Review gate**: Unit conversions work

### Step 2.4: Consolidate Queries
- [ ] Create HealthKitQueries.swift
- [ ] Move sample methods from HealthKitSamples.swift
- [ ] Move statistics methods from HealthKitStatistics.swift
- [ ] Delete old files
- **Review gate**: All data fetching works

---

## Phase 3: Generic Data Loading

**Goal**: Replace per-type DataService classes with generic loader

**Current State**:
```
BudgetDataService   - fetches calories, weight, creates BudgetService
MacrosDataService   - fetches macros, creates MacrosAnalyticsService
```

**Target State**:
```
HealthDataLoader<T> - generic observable loader
or
View-local @State with .task loading
```

### Step 3.1: Analyze data service patterns
- [ ] Document exact data flows in each service
- [ ] Identify shared vs. unique logic
- **Review gate**: Decide on generic vs. view-local approach

### Step 3.2: Extract common loading pattern
- [ ] Create shared loading infrastructure
- [ ] Migrate BudgetDataService to use it
- **Review gate**: Budget still works

### Step 3.3: Migrate MacrosDataService
- [ ] Apply same pattern to MacrosDataService
- **Review gate**: Macros still work

### Step 3.4: Clean up or remove old services
- [ ] Delete redundant code
- [ ] Document the new pattern
- **Review gate**: Clean API review

---

## Phase 4: Analytics Simplification

**Goal**: Flatten calculation hierarchy

**Current State**:
```
BudgetService
├── DataAnalyticsService (EWMA)
├── WeightAnalyticsService
│   └── DataAnalyticsService (maintenance EWMA)
└── weekIntakes, adjustment, firstWeekday

MacrosAnalyticsService
├── BudgetService reference
└── DataAnalyticsService (×3 for P/C/F)
```

**Target State**:
```
Budget calculations - pure functions or simple struct
Macro calculations - pure functions or simple struct
EWMA - standalone function
Linear regression - standalone function
```

### Step 4.1: Extract EWMA as standalone function
- [ ] Create `func computeEWMA(data:alpha:) -> Double`
- [ ] Update DataAnalyticsService to use it
- **Review gate**: Math still correct

### Step 4.2: Extract regression as standalone function
- [ ] Create `func computeWeightSlope(weights:) -> Double`
- [ ] Update WeightAnalyticsService to use it
- **Review gate**: Math still correct

### Step 4.3: Flatten BudgetService
- [ ] Inline or simplify nested services
- [ ] Consider making it a computed struct from raw data
- **Review gate**: Budget calculations work

### Step 4.4: Flatten MacrosAnalyticsService
- [ ] Simplify macro calculations
- [ ] Remove unnecessary indirection
- **Review gate**: Macro calculations work

---

## Phase 5: Infrastructure Cleanup

**Goal**: Remove over-engineered patterns

### Step 5.1: Remove Singleton protocol
- [ ] Replace SingletonQuery with direct UserGoals fetch
- [ ] Delete SingletonService.swift
- **Review gate**: Goals still load

### Step 5.2: Simplify Settings system
- [ ] Evaluate Settings<Value> wrapper necessity
- [ ] Simplify or keep based on review
- **Review gate**: Settings still work

### Step 5.3: Rename StatisticsService
- [ ] Rename to DateExtensions.swift or similar
- [ ] Clean up unrelated code
- **Review gate**: Build passes

---

## Phase 6: View Layer Cleanup (Optional)

**Goal**: Simplify view abstractions if needed

### Step 6.1: Evaluate RecordDefinition pattern
- [ ] Decide if it helps or hurts extensibility
- [ ] Keep, simplify, or remove based on review
- **Review gate**: Adding new record type is easy

### Step 6.2: Evaluate FieldDefinition pattern
- [ ] Same analysis
- **Review gate**: Form handling is simple

---

## Future Extensibility Hooks

After refactor, adding a new data type (e.g., Blood Glucose) should require:

1. **Define the type** - Add `HealthKitDataType.bloodGlucose` case
2. **Create the view** - `GlucoseView.swift` with `@State` loading
3. **Add calculations** - Pure functions if needed

No new service classes, no new data services, no boilerplate.

---

## Current Progress

- [x] Credit system overhaul (calories)
- [x] Macros simplification (remove credit banking)
- [x] Background task crash fix
- [ ] Phase 1: Observer Consolidation
- [ ] Phase 2: HealthKit Consolidation
- [ ] Phase 3: Generic Data Loading
- [ ] Phase 4: Analytics Simplification
- [ ] Phase 5: Infrastructure Cleanup
- [ ] Phase 6: View Layer Cleanup

---

## Version
- App version: 1.2.1 (in progress)
- Refactor plan: v1.0
