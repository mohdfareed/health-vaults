# HealthVaults Project Review

## Current State (Jan 6, 2026)

### Budget System

**Core Formula:**
```
Today's Budget = Maintenance + Goal + Credit Adjustment
```

**Key Concepts:**
- **Maintenance**: Calories you burn per day (learned from weight trends)
- **Credit**: Over/under from past 7 days, spread to next week reset
- **Credit Adjustment**: `credit / daysLeft`, capped at ±500 kcal/day

**Config Constants:**
| Constant | Value | Purpose |
|----------|-------|---------|
| `RegressionWindowDays` | 28 | Data window for maintenance calculation |
| `RegressionDecay` | 0.9 | Daily weight decay (recent data weighted higher) |
| `MaintenanceAlpha` | 0.1 | Long-term EWMA for maintenance intake |
| `DisplayAlpha` | 0.25 | Short-term EWMA for display |
| `MaxDailyAdjustment` | 500 | Cap on credit adjustment (kcal/day) |
| `MinWeightDataPoints` | 7 | Required for valid maintenance |
| `MinCalorieDataPoints` | 14 | Required for valid maintenance |
| `BaselineMaintenance` | 2000 | Default when data insufficient |

### Shared Settings
- `SharedDefaults` = `UserDefaults(suiteName: AppGroupID)`
- Used by both app and widgets via `@AppStorage(.key, store: SharedDefaults)`

### Widget Updates
- `AppHealthKitObserver` - listens to HealthKit changes, reloads widgets
- `AppLocale` bindings - reload on unit/firstDayOfWeek change
- `GoalsView` - reload on goals save

---

## Architecture Refactor Plan v1.0

### Phase 1: Observer Consolidation
- [ ] Inline HealthKitObservers extension into main observer
- [ ] Rename and clean up API

### Phase 2: HealthKit Layer (7 files → 3)
- [ ] Merge Authorization, DataTypes, Units into HealthKitService
- [ ] Consolidate Samples + Statistics into HealthKitQueries

### Phase 3: Generic Data Loading
- [ ] Replace per-type DataService with generic loader

### Phase 4: Analytics Simplification
- [ ] Extract EWMA and regression as standalone functions
- [ ] Flatten BudgetService and MacrosAnalyticsService

### Phase 5: Infrastructure Cleanup
- [ ] Remove Singleton protocol
- [ ] Simplify Settings system

---

## Version
- App version: 1.2.1 (in progress)
