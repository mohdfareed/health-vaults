import Foundation
import WidgetKit

// MARK: - App-Level HealthKit Observer
// ============================================================================

/// Centralized observer for HealthKit changes that triggers widget updates
/// and provides reactive notifications to views.
///
/// Uses Swift actor isolation for thread-safe state management without
/// manual dispatch queues.
public actor AppHealthKitObserver {
    /// Shared singleton instance for app-wide use.
    public static let shared = AppHealthKitObserver()

    private let healthKitService: HealthKitService
    private let notifications: HealthDataNotifications
    private nonisolated let logger = AppLogger.new(for: AppHealthKitObserver.self)

    private var isObserving = false

    private init() {
        self.healthKitService = HealthKitService.shared
        self.notifications = HealthDataNotifications.shared
    }

    /// Start observing all HealthKit data types for app-wide reactive updates.
    public func startObserving() {
        guard !isObserving else {
            logger.warning("Already observing, skipping duplicate setup")
            return
        }
        setupObservers()
    }

    /// Stop all observations.
    public func stopObserving() {
        guard isObserving else { return }

        healthKitService.stopObserving(for: "AppHealthKitObserver")
        isObserving = false
        logger.info("Stopped app-level HealthKit observer")
    }

    private func setupObservers() {
        // Calculate broad date range for all health data (covers all use cases)
        let today = Date()
        let startDate =
            today.adding(-Int(RegressionWindowDays), .day, using: .autoupdatingCurrent) ?? today
        let endDate = today.adding(1, .day, using: .autoupdatingCurrent) ?? today

        // Observe all HealthKit data types the app uses
        let dataTypes: [HealthKitDataType] = [
            .dietaryCalories, .bodyMass, .protein, .carbs, .fat, .alcohol,
        ]

        healthKitService.startObserving(
            for: "AppHealthKitObserver",
            dataTypes: dataTypes,
            from: startDate,
            to: endDate
        ) { [weak self] in
            guard let self else { return }
            Task {
                await self.onHealthKitDataChanged(dataTypes: dataTypes)
            }
        }

        isObserving = true
        logger.info(
            "Started HealthKit observer for data types: \(dataTypes.map(\.sampleType.identifier))"
        )
    }

    private func onHealthKitDataChanged(dataTypes: [HealthKitDataType]) async {
        logger.debug("HealthKit data changed for types: \(dataTypes.map(\.sampleType.identifier))")

        // Notify the HealthDataNotifications service (for view reactivity)
        await notifications.notifyDataChanged(for: dataTypes)

        // Trigger widget updates on main actor
        await refreshWidgets()
    }

    @MainActor
    private func refreshWidgets() {
        logger.debug("Refreshing all widgets due to HealthKit data changes")
        WidgetCenter.shared.reloadTimelines(ofKind: BudgetWidgetID)
        WidgetCenter.shared.reloadTimelines(ofKind: MacrosWidgetID)
    }
}
