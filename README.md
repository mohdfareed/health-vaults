# HealthVaults

A flexible calorie tracking app for iOS with rolling weekly budgets and adaptive maintenance estimation.

## Features

- **Rolling Credit System**: Unused calories carry forward within a 7-day window
- **Adaptive Maintenance**: TDEE calculated from weight trends via weighted linear regression
- **HealthKit Integration**: Bidirectional sync for calories, weight, and macros; reads body fat % for personalized energy density
- **Widgets**: WidgetKit-based budget and macro displays
- **Macro Tracking**: Protein, carbohydrate, and fat monitoring

## Budget Model

```
Budget = Maintenance + Goal + Credit Adjustment
```

| Term | Definition |
|------|------------|
| Maintenance | Estimated TDEE from weight regression |
| Goal | User-defined daily surplus/deficit |
| Credit Adjustment | `clamp(Credit / DaysLeft, ±500)` |

### Credit Calculation

```
Credit = (Base Budget × Days Logged) − Actual Intake
```

Rolling 7-day window. Only logged days contribute—missing days are excluded, not assumed zero.

### Maintenance Estimation

```
Maintenance = EWMA(Intake) − (WeightSlope × ρ)
```

- **WeightSlope**: Weighted linear regression over 28 days (decay = 0.9/day)
- **ρ (energy density)**: Personalized via Forbes partition model when body fat % is available from HealthKit; defaults to 7350 kcal/kg
- **Forbes model**: `p = FM / (FM + 10.4)`, then `ρ = p × 9440 + (1−p) × 1816` kcal/kg
- **Confidence blending**: Interpolates toward 2200 kcal baseline when data is sparse

Requires ≥7 weight measurements and ≥14 calorie entries over ≥14 days for full confidence.

## Architecture

| Layer | Components |
|-------|------------|
| UI | SwiftUI + `@Observable` pattern |
| Storage | SwiftData (local) + HealthKit (sync) |
| Analytics | `BudgetService`, `MaintenanceService`, `IntakeAnalyticsService` |
| Widgets | WidgetKit + App Groups for shared state |

## Building

**Requirements**: Xcode 26+, iOS 26+, Swift 6.2+

```bash
./Scripts/build.sh [-b|--beta]
```

**Configuration**:
1. App Groups for widget data sharing
2. HealthKit entitlements
3. Signing for app and widget targets

## Project Structure

```
App/           # Application entry points
Shared/
  Models/      # Data structures
  Services/    # Business logic, HealthKit, analytics
  Views/       # SwiftUI components
Widgets/       # Widget extension
```

## License

[MIT License](./LICENSE)

## References

- [Adaptive TDEE Spreadsheet](https://www.reddit.com/r/Fitness/comments/4mhvpn/adaptive_tdee_tracking_spreadsheet_v3_rescue/)
