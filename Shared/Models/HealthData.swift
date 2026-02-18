import Foundation
import SwiftData

// MARK: - Health Data Types
// ============================================================================

/// Supported health data model types for the app.
public enum HealthDataModel: CaseIterable, Identifiable {
    case calorie, weight, bodyFat

    /// The associated data model type.
    var dataType: any HealthData.Type {
        switch self {
        case .calorie:
            return DietaryCalorie.self
        case .weight:
            return Weight.self
        case .bodyFat:
            return BodyFatPercentage.self
        }
    }

    /// Determines data model type from instance.
    static func from(_ data: any HealthData) -> HealthDataModel {
        switch data {
        case is DietaryCalorie:
            return .calorie
        case is Weight:
            return .weight
        case is BodyFatPercentage:
            return .bodyFat
        default:
            fatalError("Unknown health data type: \(type(of: data))")
        }
    }
}

// MARK: - Data Source Tracking
// ============================================================================

/// Sources of health data entries for provenance tracking.
public enum DataSource: Codable, CaseIterable, Equatable, Sendable {
    case app, healthKit, shortcuts, foodNoms
    case other(String)

    static public var allCases: [DataSource] {
        return [
            .app, .healthKit,
            .other(String(localized: "unknown")),
        ]
    }
}

// MARK: - Health Data Protocol
// ============================================================================

/// Base protocol for all health data models.
public protocol HealthData: Identifiable, Observable {
    /// Unique identifier for the data entry.
    var id: UUID { get }
    /// Source of the data entry (app, HealthKit, etc.).
    var source: DataSource { get }
    /// Timestamp when the data was recorded.
    var date: Date { get set }
    /// Default initializer for new entries.
    init()
}

// MARK: - Query Protocol
// ============================================================================

/// Protocol for HealthKit data operations.
@MainActor public protocol HealthQuery<Data> {
    /// Associated health data type.
    associatedtype Data: HealthData

    /// Fetches data from HealthKit within date range.
    func fetch(
        from: Date, to: Date, limit: Int?,
        store: HealthKitService
    ) async -> [Data]

    /// Saves data to HealthKit.
    func save(_ data: Data, store: HealthKitService) async throws
    /// Deletes data from HealthKit.
    func delete(_ data: Data, store: HealthKitService) async throws
}
