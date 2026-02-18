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

        let writableTypes = HealthKitDataType.allCases
            .filter(\.isWritable)
            .map(\.sampleType)
        let readTypes = Set(HealthKitDataType.allCases.map(\.sampleType)) as Set<HKObjectType>
        store.requestAuthorization(
            toShare: Set(writableTypes), read: readTypes
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
        let dataTypes = HealthKitDataType.allCases
            .filter(\.isWritable)
            .map(\.sampleType)
        return dataTypes.map { isAuthorized(for: $0) }
    }
}
