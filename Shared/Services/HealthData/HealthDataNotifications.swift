import Foundation
import HealthKit
import Observation
import SwiftUI

// MARK: Health Data Change Notifications
// ============================================================================

/// Observable service for notifying views when HealthKit data changes.
///
/// Uses `@Observable` for SwiftUI reactivity. Property mutations are dispatched
/// to the main thread for UI safety.
@Observable
public final class HealthDataNotifications: @unchecked Sendable {
    /// Shared singleton instance.
    public static let shared = HealthDataNotifications()

    /// Timestamp of last data change for each data type.
    public private(set) var lastUpdate: [HealthKitDataType: Date] = [:]

    /// General data change trigger for UI updates.
    public private(set) var dataChangeTimestamp = Date()

    private nonisolated let logger = AppLogger.new(for: HealthDataNotifications.self)

    private init() {
        logger.info("HealthDataNotifications service initialized")
    }

    /// Notify that specific HealthKit data has changed.
    /// Dispatches to main thread to ensure UI updates.
    @MainActor
    public func notifyDataChanged(for dataTypes: [HealthKitDataType]) {
        let now = Date()

        for dataType in dataTypes {
            lastUpdate[dataType] = now
        }
        dataChangeTimestamp = now

        logger.debug(
            "Data change notification sent for types: \(dataTypes.map(\.sampleType.identifier))")
    }

    /// Check if specific data type has been updated since a given date.
    public func hasUpdated(dataType: HealthKitDataType, since date: Date) -> Bool {
        guard let lastUpdateTime = lastUpdate[dataType] else { return false }
        return lastUpdateTime > date
    }

    /// Get the last update time for a specific data type.
    public func getLastUpdate(for dataType: HealthKitDataType) -> Date? {
        return lastUpdate[dataType]
    }
}

// MARK: Environment Integration
// ============================================================================

extension EnvironmentValues {
    @Entry public var healthDataNotifications: HealthDataNotifications = .shared
}

// MARK: View Modifier for Auto-Refresh
// ============================================================================

/// View modifier that automatically refreshes analytics when health data changes
public struct HealthDataRefresh: ViewModifier {
    @Environment(\.healthDataNotifications) private var notifications
    let dataTypes: [HealthKitDataType]
    let onRefresh: () async -> Void

    @State private var lastRefreshTime = Date()

    public func body(content: Content) -> some View {
        content
            .onChange(of: notifications.dataChangeTimestamp) { _, _ in
                // Check if any of our watched data types have been updated
                let shouldRefresh = dataTypes.contains { dataType in
                    notifications.hasUpdated(dataType: dataType, since: lastRefreshTime)
                }

                if shouldRefresh {
                    lastRefreshTime = Date()
                    Task {
                        await onRefresh()
                    }
                }
            }
    }
}

extension View {
    /// Automatically refresh when specific HealthKit data types change
    public func refreshOnHealthDataChange(
        for dataTypes: [HealthKitDataType],
        perform refresh: @escaping () async -> Void
    ) -> some View {
        modifier(HealthDataRefresh(dataTypes: dataTypes, onRefresh: refresh))
    }
}
