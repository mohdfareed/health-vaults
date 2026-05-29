# HealthVaults

A flexible calorie tracking app for iOS with rolling weekly budgets and adaptive maintenance estimation.

## Features

- **Rolling Credit System**: Unused calories carry forward within a 7-day window
- **Adaptive Maintenance**: TDEE calculated from weight trends via weighted linear regression
- **HealthKit Integration**: Bidirectional sync for food and weight; reads body fat % for personalized energy density
- **Widgets**: Home screen budget and macro displays
- **Macro Tracking**: Protein, carbohydrate, fat, and alcohol budgeting

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

Rolling 7-day window. Only logged days contribute; missing days are excluded, not assumed zero.

### Maintenance Estimation

```
Maintenance = BlendedIntake − (BlendedSlope × ρ / 7)
```

Each component blends independently toward a neutral fallback based on its own data confidence:

- **BlendedIntake**: `EWMA(Intake) × calorieConf + fallback × (1 − calorieConf)`
  - Falls back to personal historical estimate, or 2200 kcal baseline if no history
- **BlendedSlope**: `WeightSlope × weightConf`
  - Falls back to 0 (stable weight assumed when weight data is sparse)
- **WeightSlope**: Weighted linear regression over 28 days (decay = 0.9/day)
- **ρ (energy density)**: Personalized via Forbes partition model when body fat % is available from HealthKit; defaults to 7350 kcal/kg
- **Forbes model**: `p = FM / (FM + 10.4)`, then `ρ = p × 9440 + (1−p) × 1816` kcal/kg
- **EWMA**: Gap-aware — scales effective alpha by gap size: `α_n = 1 − (1−α)^n` for n-day gaps. No fabricated data for missing days.

#### Historical Fallback

When recent (28-day) data is sparse, the fallback maintenance is estimated from personal historical data via progressive fetching:

1. Query 6 months of HealthKit data
2. If insufficient (28 > weight days or 56 > calorie days), expand to 1 year
3. If still insufficient, expand to 2 years
4. If no sufficient history exists, falls back to 2200 kcal/day baseline

This ensures returning users get a personalized estimate even after tracking gaps.

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

## References

- [Adaptive TDEE Spreadsheet](https://www.reddit.com/r/Fitness/comments/4mhvpn/adaptive_tdee_tracking_spreadsheet_v3_rescue/)
- [OTexts: Exponential smoothing](https://otexts.com/fpp2/expsmooth.html)
- [Hall, K. D. What is the required energy deficit per unit weight loss?](https://pmc.ncbi.nlm.nih.gov/articles/PMC2376744/)
- [Hall, K. D. Body fat and fat-free mass inter-relationships: Forbes's theory revisited](https://pmc.ncbi.nlm.nih.gov/articles/PMC2376748/)
- [FAO: Energy conversion factors](https://www.fao.org/3/y5022e/y5022e04.htm)
- [NIAAA: What Is a Standard Drink?](https://www.niaaa.nih.gov/alcohols-effects-health/what-standard-drink)

## License

[MIT License](./LICENSE)
