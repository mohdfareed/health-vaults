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
/// Source repository URL.
public let RepoURL = "https://github.com/mohdfareed/health-vaults"

// MARK: - Analytics Configuration
// ============================================================================

/// Number of days for weight regression window (maintenance estimation).
/// Shorter windows are more responsive to recent trends but less stable.
public let WeightRegressionDays: UInt = 30

/// Minimum days of weight data for valid regression.
public let MinWeightSpanDays = 14
/// Minimum weight measurements for valid regression.
public let MinWeightDataPoints = 5

/// Minimum days of calorie data for reliable EWMA smoothing.
public let MinCalorieSpanDays = 7
/// Minimum calorie measurements for reliable EWMA smoothing.
public let MinCalorieDataPoints = 4

/// Maximum physiological weight change rate (kg/week).
/// Fat loss is limited by energy deficit; gain by surplus + muscle synthesis.
/// Bounds: ~1 kg/week loss (extreme), ~0.5 kg/week gain (realistic).
public let MaxWeightLossPerWeek = 1.0  // kg/week
public let MaxWeightGainPerWeek = 0.5  // kg/week

/// Baseline maintenance estimate (kcal/day) used when data is insufficient.
/// Blended with calculated value based on confidence factor.
public let BaselineMaintenance = 2000.0  // kcal/day

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
