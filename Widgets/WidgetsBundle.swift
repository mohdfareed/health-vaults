import HealthVaultsShared
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - User Settings
// ============================================================================

/// Shared helper for accessing UserGoals data in widgets
@MainActor
enum WidgetsSettings {
    /// Fetches both adjustment and macros from UserGoals.
    /// Reads goalsID from SharedDefaults and falls back to any existing goals if not found.
    static func getGoals() async -> UserGoals? {
        // Read goalsID directly from SharedDefaults (key matches Settings.userGoals)
        let goalsID: UUID =
            SharedDefaults.string(forKey: "Goals")
            .flatMap { UUID(uuidString: $0) } ?? .zero

        do {
            // Use the shared App Groups container
            let container = try AppSchema.createContainer()
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
