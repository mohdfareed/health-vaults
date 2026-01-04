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

/// Minimum number of days of data required for valid maintenance estimates.
public let MinValidDataDays = 14

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
