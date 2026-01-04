# HealthVaults Project Review

## iOS 26 Modernization - Session 2

### Latest Fixes (January 2026)

#### Data Refresh Fix
- **`HealthDataNotifications`**: Simplified to plain `@Observable` class with `@unchecked Sendable`
- Removed problematic `@MainActor` isolation that conflicted with `@Entry` macro
- `notifyDataChanged` is now explicitly `@MainActor` for UI thread safety

#### Small Widget Layout
- **`SmallBudgetLayout`**: Reduced spacing, fixed icon size (50x50), tighter vertical layout
- Removed nested HStack wrapper, uses VStack with proper spacing

#### MeasurementField Improvements
- **Input width**: Added `.fixedSize(horizontal: true, vertical: false)` to TextField
- **Unit picker**: Changed from `Picker` to `Menu` with compact symbol display
- Shows unit symbol + chevron instead of full formatted value

### Architecture Summary
- **Data Sources**: HealthKit (external), SwiftData (app-generated)
- **Key Pattern**: 7-day EWMA calorie budgeting with missing-day interpolation
- **Core Analytics**: Calorie credit system + 30-day maintenance estimation
- **Widgets**: Budget and Macros widgets with Liquid Glass backgrounds
- **Concurrency**: Swift actors for observer state, `@Observable` for notifications

### Key Configuration (`Config.swift`)
| Constant | Value | Purpose |
|----------|-------|---------|
| `BudgetWidgetID` | `"BudgetWidget"` | Widget kind for WidgetCenter refresh |
| `MacrosWidgetID` | `"MacrosWidget"` | Widget kind for WidgetCenter refresh |
| `WeightRegressionDays` | `30` | Days of data for maintenance estimation |
| `MinValidDataDays` | `14` | Minimum data for valid estimates |

### Data Flow
```
HealthKit → AppHealthKitObserver (actor)
         → HealthDataNotifications (@Observable)
         → Views via .refreshOnHealthDataChange modifier
         → WidgetCenter.reloadTimelines
```

### Version
- App version: 1.1 (build 1)
