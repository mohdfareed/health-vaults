import Foundation
import HealthKit

// MARK: Authorization
// ============================================================================

/// The authorization status for HealthKit data types.
public enum HealthAuthorizationStatus {
    case noAccess
    case authorized
    case partiallyAuthorized
}

extension HealthKitService {
    /// Request authorization for all required health data types.
    public func requestAuthorization(
        completion: (@MainActor @Sendable () -> Void)? = nil
    ) {
        guard Self.isAvailable else {
            logger.warning("HealthKit not available on this device")
            Task { @MainActor in
                completion?()
            }
            return
        }

        let dataTypes = HealthKitDataType.allCases.map { $0.sampleType }
        // Body fat percentage is read-only (used for personalized energy density)
        let readTypes = Set(dataTypes) as Set<HKObjectType>
        let extraReadTypes: Set<HKObjectType> = [
            HKQuantityType(.bodyFatPercentage)
        ]
        store.requestAuthorization(
            toShare: Set(dataTypes), read: readTypes.union(extraReadTypes)
        ) { [weak self] success, error in
            if let error = error {
                self?.logger.error("HealthKit authorization failed: \(error)")
            }

            Task { @MainActor in
                completion?()
            }
        }
    }

    /// Check authorization status for a specific data type.
    public func isAuthorized(for type: HKObjectType) -> HKAuthorizationStatus {
        return store.authorizationStatus(for: type)
    }

    /// Check the overall authorization status for all health data types.
    public func authorizationStatus() -> HealthAuthorizationStatus {
        let statuses = requiredWriteAuthorizationStatuses()

        if statuses.allSatisfy({ $0 == .sharingAuthorized }) {
            return .authorized
        }

        if statuses.contains(.sharingAuthorized) {
            return .partiallyAuthorized
        }

        return .noAccess
    }

    /// Returns authorization statuses for required writable types.
    /// `authorizationStatus(for:)` reflects sharing permission, so read-only types
    /// should not be included in this aggregate state.
    private func requiredWriteAuthorizationStatuses() -> [HKAuthorizationStatus] {
        let dataTypes = HealthKitDataType.allCases.map(\.sampleType)
        return dataTypes.map { isAuthorized(for: $0) }
    }
}
