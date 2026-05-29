# HealthVaults Project Review

## Architecture

**Data Flow:**
- **HealthKit** → source of truth for health metrics
- **SwiftData** → local store for app-created entries, synced to HealthKit
- **AppStorage** → user preferences (units, theme, goals)
- **DataQuery** → property wrapper for paginated HealthKit queries
- **HealthDataNotifications** → observable service for data change events

**Key Components:**

| Component | Purpose |
|-----------|---------|
| `DataQuery` | Paginated HealthKit query with `reload()`, `loadNextPage()`, `removeItem()` |
| `HealthDataNotifications` | Notifies views when HealthKit data changes |
| `.refreshOnHealthDataChange` | View modifier that triggers action on data change |
| `RecordList` | Uses `DataQuery` + `refreshOnHealthDataChange` for reactive updates |
| `BudgetDataService` | Calculates daily budget from maintenance + goal + credit |
| `WidgetDataCache` | Caches last-known-good analytics in SharedDefaults for widget fallback |

## Budget System

```
Today's Budget = Maintenance + Goal + Credit Adjustment
```

- **Maintenance**: TDEE learned from weight trends via EWMA + WLS regression
- **Credit**: `baseBudget × daysLogged − thisWeekIntake` (week-aligned)
- **Credit Adjustment**: `credit / daysLeft`, capped at ±500 kcal/day
- **Safety**: floor 1000, ceiling 6000 kcal/day

**Analytics Pipeline:** EWMA intake → WLS weight slope → Forbes ρ → Confidence blend → Maintenance → Budget

**Flags:** `isSlopeClamped`, `isRhoEstimated`, `isMaintenanceSuspect`, `isAdjustmentClamped`, `isBudgetClamped`

**AccuracyNote** (BudgetComponent): 5 conditions shown under budget card — calibrating, safety, suspect maintenance, unknown BF%, unusual trend.

## Key Patterns

- `.task` with `hasLoaded` guard for one-time loads
- `.refreshOnHealthDataChange` for reactive data updates
- `DataQuery.removeItem()` for optimistic deletes
- `hasAppeared` state to control animations on initial load
- Observer retries: max 3, exponential backoff, then give up
- BF% stored as fraction (0–1) in HealthKit, displayed as percentage (0–100)
- Record lists support period bucketing (All/Day/Week/Month) with aggregate values

## Icon Convention (Design.swift)

| Concept | Icon | Color |
|---------|------|-------|
| Calories | `flame.fill` | `.calories` |
| Maintenance | `flame.gauge.open` (hierarchical) | `.calories` |
| Adjustment | `plusminus.circle` (hierarchical) | `.calories` |
| Budget | `target` | `.calories` |
| Credit | `creditcard.circle` (hierarchical) | context (green/red) |
| Weight | `figure` | `.weight` (.purple) |
| Body Fat | `percent` | `.bodyFat` (.purple) |
| Protein | custom `meat` | `.protein` |
| Carbs | custom `bread` | `.carbs` (.orange) |
| Fat | custom `avocado` | `.fat` (.green) |
| Alcohol | `wineglass` | `.alcohol` (.indigo) |

## Test Infrastructure

- **118 tests** across 5 suites, all passing
- `swift test` for unit tests (~0.1s); Xcode for UI tests
- `Tests/TestHelpers.swift` — shared factories: `daysAgo()`, `constantWeights()`, `linearWeightTrend()`, etc.
- `Tests/ScenarioTests.swift` — 35 life-scenario tests in 8 groups with biological invariant checks

## ModelLab

- `ModelLab/model.py` — Python reimpl of IntakeAnalytics, Maintenance, Budget math
- `ModelLab/constants.py` — mirrors Config.swift (Tunable vs Literature)
- `ModelLab/sim.py` — Scenario generator + 6-panel pipeline plotter (`Scenario`, `generate()`, `plot_pipeline()`)
- `ModelLab/lab.ipynb` — Sub-model reference charts (EWMA, WLS, Forbes, Confidence, Convergence, Budget)
- `ModelLab/maintenance.ipynb` — Pipeline explorer: run scenarios through full maintenance calc, see every stage
- `Scripts/lab.sh` — launches Jupyter via venv + pip
- Open questions tracked in `Docs/PLAN_MODEL.md`

## Key Decisions

| Date | Decision | Why |
|------|----------|-----|
| Feb 22 | PLAN.md fully implemented | All bugs 1-4, additional fixes verified passing (118 tests) |
| Feb 16 | Observer retries capped at 3 | Infinite retry caused background crashes |
| Feb 16 | Widget data cache in SharedDefaults | Fallback when fresh HealthKit data is invalid |
| Feb 16 | Analytics types made Codable | Widget caching + referenceDate for consistency |
| Feb 17 | BF% promoted to first-class HealthKitDataType | Window-scoped time-series for Forbes ρ |
| Feb 17 | Permission copy rewritten | Explain user benefit, not just technical read/write |
| Feb 17 | Overview redesigned as diagnostic report | Screenshot-friendly, shows algorithm internals |
| Feb 19 | Historical thresholds aligned with primary | Separate stricter gates caused 0% confidence bug |
| Feb 19 | HistoricalFetchStages extended to 10 years | Any personal data beats baseline 2200 |
| Feb 2026 | Safety floor/ceiling/flags added | Budget could reach 0; no metabolic adaptation warning |
| Feb 21 | Scope rules added to AGENTS.md | Over-engineered ModelLab; solo project needs tight scope |

## Version
- App version: 1.6 (build 1)
