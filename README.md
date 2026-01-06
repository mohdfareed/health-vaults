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

### Implementation Parameters

| Parameter      | Value        | Description                       |
| -------------- | ------------ | --------------------------------- |
| EWMA α         | 0.25         | 7-day smoothing factor            |
| Energy/Weight  | 7700 kcal/kg | Conservative energy equivalent    |
| Weight Window  | 30 days      | Regression period for maintenance |

### Data Validation

Estimates require minimum data to prevent unreliable calculations from sparse inputs.

| Data Source | Min Points | Min Span | Baseline | Effect |
|-------------|------------|----------|----------|--------|
| Weight      | 5          | 14 days  | 0 kg/wk  | Slope blended toward baseline, clamped to ±1 kg/wk |
| Calories    | 4          | 7 days   | 2000 kcal/day | Maintenance blended toward baseline |

**Confidence factor** (0–1): `(points / minPoints) × (days / minSpan)`

**Blending formula**: `value = raw × confidence + baseline × (1 - confidence)`

With sparse data, estimates smoothly converge to sensible defaults rather than producing nil or erratic values.

### Core Algorithms

#### 1. Calorie Credit System

**Weekly Credit** (cumulative actual vs. target):
$\text{Credit}_t = B \cdot d - \sum_{i=1}^{d} C_i$

Where:
- $B$ is the base daily budget (maintenance + adjustment)
- $d$ is days elapsed since week start (not including today)
- $C_i$ is actual intake on day $i$

**Adjusted Budget** (distributes credit across remaining days):
$B'_t = B + \frac{\text{Credit}_t}{D}$

Where $D$ is days remaining in weekly cycle (including today).

#### 2. Maintenance Estimation

**EWMA Smoothing** (30-day window):
$S_t = \alpha \cdot C_{t-1} + (1 - \alpha) \cdot S_{t-1}$

**Weight Trend** (Linear regression):
$m = \frac{\sum(i - \bar{i})(w_i - \bar{w})}{\sum(i - \bar{i})^2}$

**Energy Imbalance**:
$\Delta E = m \times \rho$

**Maintenance Estimate**:
$M = S_t - \Delta E$

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
