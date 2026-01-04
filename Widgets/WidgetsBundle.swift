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
        if #available(iOS 26.0, *) {
            // iOS 26: Use Liquid Glass effect for modern translucent appearance
            self.containerBackground(for: .widget) {
                Color.clear.glassEffect()
            }
        } else if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            self
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
