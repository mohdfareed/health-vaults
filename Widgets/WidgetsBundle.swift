import HealthVaultsShared
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - User Settings
// ============================================================================

/// Shared helper for accessing UserGoals data in widgets
@MainActor
enum WidgetsSettings {
    /// Fetches both adjustment and macros from UserGoals
    static func getGoals(for goalsID: UUID) async -> UserGoals? {
        do {
            // Use the shared App Groups container
            let container = try AppSchema.createContainer()
            let context = ModelContext(container)

            var descriptor = FetchDescriptor<UserGoals>(
                predicate: UserGoals.predicate(id: goalsID),
                sortBy: [.init(\.persistentModelID)]
            )
            descriptor.fetchLimit = 1

            let goals = try context.fetch(descriptor)
            return goals.first
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
