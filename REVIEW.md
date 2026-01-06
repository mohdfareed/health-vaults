# HealthVaults Project Review

## Current State (Jan 5, 2026)

### Analytics System
**Unified 28-day Window** for calorie/weight analytics:
- Confidence: `(points/minPoints) × (span/windowDays)`
- Maintenance blends toward 2000 kcal baseline when confidence is low
- Credit system works without requiring full calibration

**Config Constants:**
| Constant | Value | Purpose |
|----------|-------|---------|
| `RegressionWindowDays` | 28 | Window for regression + confidence |
| `MinWeightDataPoints` | 7 | ~2 measurements per week |
| `MinCalorieDataPoints` | 14 | ~50% of days tracked |
| `BaselineMaintenance` | 2000 | Default when data insufficient |

### Shared Settings
- `SharedDefaults` = `UserDefaults(suiteName: AppGroupID)`
- Used by both app and widgets via `@AppStorage(.key, store: SharedDefaults)`
- Settings changed in app immediately available to widgets

### Widget Updates
**Primary Mechanisms:**
- `AppHealthKitObserver` - listens to HealthKit changes, reloads specific widgets
- `AppLocale` bindings - reload on unit system or firstDayOfWeek change
- `GoalsView` - reload on goals save
- Background refresh task - periodic refresh

**Note:** Widgets run in separate processes - HealthKit observer in widgets is pointless.

---

## Architecture Refactor Plan v1.0

### Phase 1: Observer Consolidation
**Goal:** Merge observer mechanisms into single `HealthKitObserver`

- [ ] Step 1.3: Inline HealthKitObservers extension into main observer
- [ ] Step 1.4: Rename and clean up API

### Phase 2: HealthKit Layer (7 files → 3)
- [ ] Merge Authorization, DataTypes, Units into HealthKitService
- [ ] Consolidate Samples + Statistics into HealthKitQueries

### Phase 3: Generic Data Loading
- [ ] Replace per-type DataService with generic loader or view-local loading

### Phase 4: Analytics Simplification
- [ ] Extract EWMA and regression as standalone functions
- [ ] Flatten BudgetService and MacrosAnalyticsService

### Phase 5: Infrastructure Cleanup
- [ ] Remove Singleton protocol
- [ ] Simplify Settings system

---

## Version
- App version: 1.2.1 (in progress)
