import SwiftData
import SwiftUI

// TODO: Create reusable goals the user can choose from.
// TODO: Create calorie entries preset system.

// MARK: - App Configuration
// ============================================================================

/// App name for display purposes.
public let AppName = String(localized: "HealthVaults")
/// App bundle identifier for entitlements and configuration.
public let AppID = "com.MohdFareed.HealthVaults"

/// Budget widget identifier for WidgetKit.
/// Uses a simple, stable string that matches between widget definition and refresh calls.
public let BudgetWidgetID = "BudgetWidget"
/// Macros widget identifier for WidgetKit.
/// Uses a simple, stable string that matches between widget definition and refresh calls.
public let MacrosWidgetID = "MacrosWidget"
/// HealthKit observers dispatch queue identifier.
public let ObserversID = "\(AppID).Observers"
/// App Groups container for shared data between app and widgets.
public let AppGroupID = "group.\(AppID).shared"
/// Shared UserDefaults for App Group (used by both app and widgets).
public nonisolated(unsafe) let SharedDefaults = UserDefaults(suiteName: AppGroupID) ?? .standard
/// Source repository URL.
public let RepoURL = "https://github.com/mohdfareed/health-vaults"

// MARK: - Analytics Configuration
// ============================================================================

/// Unified regression window for maintenance estimation (days).
/// 28 days (4 weeks) is the scientifically recommended minimum for
/// reliable TDEE estimation via weight tracking.
public let RegressionWindowDays: UInt = 28

/// Weighted regression decay factor (per day).
/// Controls how quickly old weight data loses influence.
/// 0.9 → last 7 days ≈ 52% of total weight in regression.
public let RegressionDecay = 0.9

/// EWMA alpha for maintenance calculation (long-term intake pattern).
/// Low value = stable, ignores single-day spikes.
/// 0.1 → ~2 week half-life, reflects sustained eating patterns.
public let MaintenanceAlpha = 0.1

/// EWMA alpha for display purposes (recent intake pattern).
/// Higher value = responsive to recent changes.
/// 0.25 → ~3 day half-life, shows current eating pattern.
public let DisplayAlpha = 0.25

/// Minimum data points required for full confidence.
/// ~2 measurements per week over 4 weeks.
public let MinWeightDataPoints = 7
/// Minimum calorie tracking days for full confidence.
/// ~50% of days in the window should be tracked.
public let MinCalorieDataPoints = 14

/// Maximum physiological weight change rate (kg/week).
/// Fat loss is limited by energy deficit; gain by surplus + muscle synthesis.
/// Bounds: ~1 kg/week loss (extreme), ~0.75 kg/week gain (lean bulk + fat).
public let MaxWeightLossPerWeek = 1.0  // kg/week
public let MaxWeightGainPerWeek = 0.75  // kg/week

/// Maximum daily budget adjustment from credit (kcal).
/// Prevents extreme budgets when credit is very positive/negative.
public let MaxDailyAdjustment = 500.0  // kcal/day

/// Baseline maintenance estimate (kcal/day) used when data is insufficient.
/// Blended with calculated value based on confidence factor.
/// 2200 is the population-weighted average TDEE (male ~2500, female ~2000).
public let BaselineMaintenance = 2200.0  // kcal/day

// MARK: Forbes Partition Model
// Energy density of weight change depends on body composition.
// Forbes (2000), Hall (2008): tissue-specific energy densities.

/// Energy density of adipose tissue (kcal/kg). Adipose is ~87% lipid.
public let FatTissueEnergy = 9_440.0  // kcal/kg
/// Energy density of fat-free mass (kcal/kg). Hydrated lean tissue
/// including protein turnover and glycogen.
public let LeanTissueEnergy = 1_816.0  // kcal/kg
/// Forbes constant (kg). Controls fat vs lean partitioning as a function
/// of total fat mass: p = FM / (FM + C), where p is the fat fraction.
public let ForbesConstant = 10.4  // kg
/// Default energy density (kcal/kg) when body fat % is unknown.
/// Corresponds to ~34% body fat (population average).
public let DefaultRho = 7_350.0  // kcal/kg

// MARK: Historical Maintenance Fallback
// Progressive fetch stages for personal historical TDEE estimation.
// When recent (28-day) data is sparse, blends toward a personal historical
// estimate instead of the generic BaselineMaintenance.

/// Progressive fetch stages (days) for historical data.
/// Starts narrow and expands until enough data is found or the cap is reached.
/// 2-year cap: BMR declines ~1-2%/year from aging and major life changes
/// can shift TDEE significantly beyond this horizon.
public let HistoricalFetchStages: [UInt] = [180, 365, 730]

/// Minimum weight data points for a reliable historical maintenance estimate.
/// 28 distinct weigh-in days (~1/week for 6 months) ensures a stable regression.
public let MinHistoricalWeightDataPoints = 28

/// Minimum calorie tracking days for a reliable historical maintenance estimate.
/// 56 logged days (~50% adherence over 4 months) ensures EWMA convergence.
public let MinHistoricalCalorieDataPoints = 56

// MARK: - SwiftData Schema
// ============================================================================

/// App's SwiftData schema with App Groups support.
public enum AppSchema {
    @MainActor public static let schema = Schema([UserGoals.self])

    /// Creates ModelContainer configured for App Groups data sharing.
    @MainActor public static func createContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppGroupID)
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
