import Foundation
import HealthKit
import SwiftUI

// MARK: Service
// ============================================================================

/// Service for querying HealthKit data with model-specific query methods.
public class HealthKitService: @unchecked Sendable {
    internal static let shared = HealthKitService()
    internal let logger = AppLogger.new(for: HealthKitService.self)
    internal let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // Sample query sorting
    internal var defaultSortDescriptor: NSSortDescriptor {
        NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate, ascending: false
        )
    }

    // User unit preferences
    @MainActor
    internal static var unitsCache: [HKQuantityType: Unit] = [:]

    // Observation management
    internal var activeObservers: [String: HKObserverQuery] = [:]
    internal var observerRetryCounts: [String: Int] = [:]
    internal let maxObserverRetries = 3
    internal let observerQueue = DispatchQueue(
        label: ObserversID, qos: .utility
    )

    // NotificationCenter observer token
    internal var unitObserverToken: (any NSObjectProtocol)?

    private init() {
        guard Self.isAvailable else {
            logger.debug("HealthKit unavailable, skipping initialization")
            return
        }

        Task {
            await setupUnits()
            await setupBackgroundDelivery()
        }
        logger.info("HealthKit service initialized")
    }

    /// Enable background delivery for widget data types.
    @MainActor
    private func setupBackgroundDelivery() async {
        let dataTypes = HealthKitDataType.allCases.map { $0.sampleType }
        for dataType in dataTypes {
            store.enableBackgroundDelivery(
                for: dataType, frequency: .immediate
            ) { [weak self] success, error in
                if let error = error {
                    let id = dataType.identifier
                    let msg = error.localizedDescription
                    self?.logger.error(
                        "Failed to enable background delivery for \(id): \(msg)"
                    )
                }
            }
        }
    }
}

// MARK: Environment Integration
// ============================================================================

extension EnvironmentValues {
    /// The HealthKit service used for querying HealthKit data.
    @Entry public var healthKit: HealthKitService = .shared
}
