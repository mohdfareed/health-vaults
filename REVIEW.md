# HealthVaults Project Review

## Version 1.2.1 - Refinements

### Latest Fixes (January 2026)

#### Credit System Overhaul
- **Problem**: Credit was always 0 when maintenance wasn't calibrated because both were derived from EWMA
- **Fix**: Changed from `Credit = Budget - EWMA` to cumulative weekly tracking
- **New Formula**: `Credit = (Budget × days_elapsed) - actual_intake_this_week`
- Added `previous()` date helper for finding week start
- Added `weekIntakes` to BudgetService for actual daily intake tracking
- Credit now represents real banked/spent calories that map to expected weight change

#### Background Task Crash Fix
- **Problem**: BGTaskScheduler runs on background queue, but handler captured `self` causing isolation violation
- **Fix**: Changed `handleWidgetRefresh` and `scheduleBackgroundRefresh` to static methods

### Architecture Summary
- **Data Sources**: HealthKit (external), SwiftData (app-generated)
- **Maintenance**: 30-day EWMA + weight regression for TDEE estimation
- **Credit**: Cumulative weekly (actual vs target), resets each week
- **Widgets**: Budget and Macros widgets with background delivery
- **Concurrency**: Swift actors for observer state, `@Observable` for notifications

### Key Configuration (`Config.swift`)
| Constant | Value | Purpose |
|----------|-------|---------|
| `BudgetWidgetID` | `"BudgetWidget"` | Widget kind for WidgetCenter refresh |
| `MacrosWidgetID` | `"MacrosWidget"` | Widget kind for WidgetCenter refresh |
| `WeightRegressionDays` | `30` | Days of data for maintenance estimation |
| `MinValidDataDays` | `14` | Minimum data for valid estimates |

### Credit System Math
```
Credit = B × d - Σ(intake from week start to yesterday)
Adjusted = B + Credit / days_remaining
Remaining = Adjusted - today's_intake
```
Where B = maintenance + adjustment, d = days elapsed since week start

### Version
- App version: 1.2.1 (in progress)
