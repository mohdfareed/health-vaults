import HealthVaultsShared
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - User Settings
// ============================================================================

/// Shared helper for accessing UserGoals data in widgets
@MainActor
enum WidgetsSettings {
    /// Cached ModelContainer to avoid recreating it on every timeline generation.
    private static var cachedContainer: ModelContainer?

    /// Returns a shared ModelContainer, creating it only once per extension lifecycle.
    private static func container() throws -> ModelContainer {
        if let cached = cachedContainer { return cached }
        let container = try AppSchema.createContainer()
        cachedContainer = container
        return container
    }

    /// Fetches both adjustment and macros from UserGoals.
    /// Reads goalsID from SharedDefaults and falls back to any existing goals if not found.
    static func getGoals() async -> UserGoals? {
        // Read goalsID directly from SharedDefaults (key matches Settings.userGoals)
        let goalsID: UUID =
            SharedDefaults.string(forKey: "Goals")
            .flatMap { UUID(uuidString: $0) } ?? .zero

        do {
            // Use the shared App Groups container (cached)
            let container = try container()
            let context = ModelContext(container)

            // First try to fetch by exact ID
            var descriptor = FetchDescriptor<UserGoals>(
                predicate: UserGoals.predicate(id: goalsID),
                sortBy: [.init(\.persistentModelID)]
            )
            descriptor.fetchLimit = 1

            let goals = try context.fetch(descriptor)
            if let found = goals.first {
                return found
            }

            // Fallback: fetch any existing UserGoals record
            var fallbackDescriptor = FetchDescriptor<UserGoals>(
                sortBy: [.init(\.date, order: .reverse)]
            )
            fallbackDescriptor.fetchLimit = 1

            let fallbackGoals = try context.fetch(fallbackDescriptor)
            return fallbackGoals.first
        } catch {
            AppLogger.new(for: self)
                .error("Failed to fetch UserGoals: \(error)")
            return nil
        }
    }
}

// MARK: - Widget Data Cache
// ============================================================================

/// Lightweight cache for last-known-good widget data in SharedDefaults.
/// Prevents widgets from resetting to baseline when HealthKit queries
/// fail or the extension is resource-constrained.
enum WidgetDataCache {
    private static let budgetKey = "CachedBudgetService"
    private static let macrosKey = "CachedMacrosService"
    private static let logger = AppLogger.new(for: WidgetDataCache.self)

    /// Save a successful BudgetService to SharedDefaults.
    static func saveBudget(_ service: BudgetService) {
        do {
            let data = try JSONEncoder().encode(service)
            SharedDefaults.set(data, forKey: budgetKey)
            logger.debug("Cached budget data (\(data.count) bytes)")
        } catch {
            logger.error("Failed to cache budget data: \(error)")
        }
    }

    /// Load the last-known-good BudgetService from SharedDefaults.
    static func loadBudget() -> BudgetService? {
        guard let data = SharedDefaults.data(forKey: budgetKey) else {
            return nil
        }
        do {
            let service = try JSONDecoder().decode(BudgetService.self, from: data)
            logger.debug("Loaded cached budget data")
            return service
        } catch {
            logger.error("Failed to decode cached budget data: \(error)")
            return nil
        }
    }

    /// Save a successful MacrosAnalyticsService to SharedDefaults.
    static func saveMacros(_ service: MacrosAnalyticsService) {
        do {
            let data = try JSONEncoder().encode(service)
            SharedDefaults.set(data, forKey: macrosKey)
            logger.debug("Cached macros data (\(data.count) bytes)")
        } catch {
            logger.error("Failed to cache macros data: \(error)")
        }
    }

    /// Load the last-known-good MacrosAnalyticsService from SharedDefaults.
    static func loadMacros() -> MacrosAnalyticsService? {
        guard let data = SharedDefaults.data(forKey: macrosKey) else {
            return nil
        }
        do {
            let service = try JSONDecoder().decode(MacrosAnalyticsService.self, from: data)
            logger.debug("Loaded cached macros data")
            return service
        } catch {
            logger.error("Failed to decode cached macros data: \(error)")
            return nil
        }
    }
}

// MARK: - Widget Background Helper
// ============================================================================

extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        self.containerBackground(for: .widget) {
            Color.widgetBackground
        }
    }
}

// MARK: - Widget Bundle
// ============================================================================

@main
struct WidgetsBundle: WidgetBundle {
    var body: some Widget {
        BudgetWidget()
        MacrosWidget()
    }
}
