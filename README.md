# HealthVaults

HealthVaults is an iOS application that provides a flexible, insight-driven approach to health tracking. Unlike traditional calorie counting apps that reset daily budgets, HealthVaults uses **7-day running average budgeting** to provide a more realistic and sustainable approach to nutrition management.

Built with SwiftUI and integrated with Apple HealthKit, the app tracks calorie intake, weight trends, and macro-nutrients while providing intelligent budget adjustments based on weekly patterns.

## Features

- **Smart Budgeting**: 7-day EWMA smoothing for realistic calorie budgeting
- **Maintenance Estimation**: Automatic calculation of daily maintenance calories from weight trends
- **Apple Health Integration**: Seamless data sync with HealthKit
- **Widget Support**: Home screen widgets for quick budget and macro tracking
- **Macro Tracking**: Detailed protein, carbohydrate, and fat monitoring

## Architecture

### Technology Stack
- **Frontend**: SwiftUI with reactive `@Observable` pattern
- **Data Storage**: SwiftData (app-generated) + HealthKit (external)
- **Widgets**: WidgetKit with App Groups data sharing
- **Analytics**: Custom EWMA and linear regression algorithms

### Data Flow
1. **Input**: User entries via SwiftUI forms
2. **Storage**: SwiftData → HealthKit synchronization
3. **Analytics**: Combined data processing with EWMA smoothing
4. **Display**: Reactive UI updates and widget refresh

## Mathematical Specification

### Core Concept

HealthVaults estimates your **maintenance calories** (TDEE) from actual weight change and calorie intake data, then provides a flexible **weekly budget** that lets you balance high and low days.

### Implementation Parameters

| Parameter           | Value        | Description                          |
| ------------------- | ------------ | ------------------------------------ |
| Regression Window   | 28 days      | Data window for all calculations     |
| EWMA α              | 0.25         | ~7-day half-life smoothing factor    |
| Energy Density (ρ)  | 7700 kcal/kg | Energy per kg body mass change       |
| Baseline Maintenance| 2000 kcal    | Default when data is insufficient    |
| Max Weight Loss     | 1.0 kg/week  | Physiological clamp                  |
| Max Weight Gain     | 0.5 kg/week  | Physiological clamp                  |

### Confidence System

Estimates require sufficient data within the 28-day window to be reliable. Confidence considers both **density** (how many data points) and **span** (how much time they cover).

| Data Source | Min Points | For Full Confidence |
|-------------|------------|---------------------|
| Weight      | 7          | ~2 measurements/week |
| Calories    | 14         | ~50% of days tracked |

**Confidence formula**:
$$\text{confidence} = \frac{\text{points}}{\text{minPoints}} \times \frac{\text{span}}{28}$$

Both factors are capped at 1.0, so confidence ranges from 0 to 1.

**Validity**: Data is considered valid when `points ≥ minPoints` AND `span ≥ 14 days`.

### Core Algorithms

#### 1. Maintenance Estimation

The fundamental equation: if you're gaining/losing weight, your maintenance equals your intake minus the energy stored/released.

**Step 1: EWMA-Smoothed Intake**

Exponentially weighted moving average reduces day-to-day noise:
$$S_t = \alpha \cdot C_{t} + (1 - \alpha) \cdot S_{t-1}$$

Where $\alpha = 0.25$ gives ~7-day effective averaging. Missing days are filled with the period average to prevent gaps from skewing results.

**Step 2: Weight Slope via Linear Regression**

Least-squares regression on daily weights within the 28-day window:
$$m = \frac{\sum(t_i - \bar{t})(w_i - \bar{w})}{\sum(t_i - \bar{t})^2} \quad \text{(kg/day)}$$

Convert to weekly rate and clamp to physiological bounds:
$$m_{\text{clamped}} = \text{clamp}(m \times 7, -1.0, +0.5) \quad \text{(kg/week)}$$

**Step 3: Raw Maintenance**

Energy imbalance equals weight change times energy density:
$$M_{\text{raw}} = S_t - \frac{m_{\text{clamped}} \times \rho}{7}$$

**Step 4: Confidence Blending**

Blend toward baseline when data is insufficient:
$$M = M_{\text{raw}} \times \text{confidence} + 2000 \times (1 - \text{confidence})$$

#### 2. Calorie Credit System

Unused calories roll over within the week, allowing flexibility. Week starts based on your **First Weekday** setting.

**Weekly Credit** (what you've "banked" so far):
$$\text{Credit}_t = B \cdot d - \sum_{i=1}^{d} C_i$$

Where:
- $B$ = base daily budget (maintenance + user adjustment)
- $d$ = days elapsed since week start (excluding today)
- $C_i$ = actual intake on day $i$

**Adjusted Budget** (today's budget including credit):
$$B'_t = B + \frac{\text{Credit}_t}{D}$$

Where $D$ = days remaining in week (including today).

Example: if you under-ate by 500 kcal over the first 3 days, you have 500 kcal credit spread across the remaining 4 days (+125/day).

## Building

### Requirements
- Xcode 26.0+
- iOS 26.0+ deployment target
- Swift 6.2+

### Build Commands
```bash
# Build the project
./Scripts/build.sh [-b|--beta]
```
where `-b|--beta` uses the beta Xcode command line tools.

### Configuration
1. Configure App Groups in Xcode for widget data sharing
2. Enable HealthKit entitlements for background delivery
3. Configure signing for both app and widget targets

## Development

### Project Structure
```
├── App/                # Main application
├── Shared/             # Shared code
│   ├── Models/         # Data models and protocols
│   ├── Services/       # Business logic and HealthKit
│   └── Views/          # SwiftUI components
├── Widgets/            # Widget extension
└── Scripts/            # Build automation
```

### Key Patterns
- **Data Models**: Observable classes with HealthKit sync
- **Services**: Dependency injection with environment values
- **Views**: Reactive with automatic refresh on data changes
- **Analytics**: Pure value types for mathematical operations

## License

This project is licensed under the [MIT License](./LICENSE).

## Resources:

- https://www.reddit.com/r/Fitness/comments/4mhvpn/adaptive_tdee_tracking_spreadsheet_v3_rescue/?rdt=45879
