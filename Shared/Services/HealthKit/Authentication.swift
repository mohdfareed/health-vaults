import Foundation
import HealthKit

// MARK: Authorization
// ============================================================================

/// The authorization status for HealthKit data types.
public enum HealthAuthorizationStatus {
    case notReviewed
    case authorized
    case denied
    case partiallyAuthorized
}

extension HealthKitService {
    /// Request authorization for all required health data types.
    public func requestAuthorization() {
        guard Self.isAvailable else {
            logger.warning("HealthKit not available on this device")
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
        }
    }

    /// Check authorization status for a specific data type.
    public func isAuthorized(for type: HKObjectType) -> HKAuthorizationStatus {
        return store.authorizationStatus(for: type)
    }

    /// Check the overall authorization status for all health data types.
    public func authorizationStatus() -> HealthAuthorizationStatus {
        if !isReviewed() {
            return .notReviewed
        } else if isAuthorized() {
            return .authorized
        } else if isDenied() {
            return .denied
        } else {
            return .partiallyAuthorized
        }
    }

    /// Check if the app has complete authorization for all types.
    private func isAuthorized() -> Bool {
        return HealthKitDataType.allCases.allSatisfy { type in
            isAuthorized(for: type.sampleType) == .sharingAuthorized
        }
    }

    /// Check if the user has reviewed the permissions for all types.
    private func isReviewed() -> Bool {
        return HealthKitDataType.allCases.allSatisfy { type in
            isAuthorized(for: type.sampleType) != .notDetermined
        }
    }

    /// Check if the user has denied permissions for all types.
    private func isDenied() -> Bool {
        return HealthKitDataType.allCases.allSatisfy { type in
            isAuthorized(for: type.sampleType) == .sharingDenied
        }
    }
}
