import Foundation
import HealthKit
import SwiftData

// MARK: Singleton
// ============================================================================

/// A protocol for models with an ID trackable in the `UserDefaults` database.
/// The ID can be attributed with `.unique` with `UUID.zero` as the default
/// to guarantee a single instance of the model in the database. The singleton
/// must provide a default value through the `init()` method.
public protocol Singleton: PersistentModel where Self.ID == UUID {
    init(id: UUID)
    /// The predicate generator.
    /// This is required to use stored properties on a protocol.
    static func predicate(id: UUID) -> Predicate<Self>
}

// MARK: Units System
// ============================================================================

/// The unit localization definition.
public struct UnitDefinition<D: Dimension>: Sendable {
    /// The display unit to use if not localized.
    let baseUnit: D
    /// The alternative units allowed for the unit.
    let altUnits: [D]
    /// The unit formatting usage.
    let usage: MeasurementFormatUnitUsage<D>
    // The HealthKit unit type.
    let healthKitType: HealthKitDataType?

    init(
        _ unit: D = .baseUnit(), alts: [D] = [],
        usage: MeasurementFormatUnitUsage<D> = .general,
        healthKitType: HealthKitDataType? = nil,
    ) {
        self.baseUnit = unit
        self.altUnits = alts
        self.healthKitType = healthKitType
        self.usage = usage
    }
}

// MARK: Settings System
// ============================================================================

/// A protocol to define the raw value stored in the `UserDefaults` database.
public protocol SettingsValue: Sendable {}
/// A protocol to define a settings value that can be stored as a string.
/// New settings value types can be created by implementing this protocol.
public typealias StringSettingsValue = SettingsValue & RawRepresentable<String>
/// A protocol to define a settings value that can be stored as an integer.
/// New settings value types can be created by implementing this protocol.
public typealias IntSettingsValue = SettingsValue & RawRepresentable<Int>

/// A key for a settings value stored in the `UserDefaults` database.
/// It must be sendable to allow the key to be reused throughout the app.
public struct Settings<Value: SettingsValue>: Sendable {
    /// The unique key for the value in `UserDefaults`.
    let id: String
    /// The default value for the setting.
    let `default`: Value

    init(_ id: String, default: Value) {
        self.id = id
        self.default = `default`
    }
    init(_ id: String, default: Value = nil)
    where Value: ExpressibleByNilLiteral {
        self.id = id
        self.default = `default`
    }
}

/// A type-erased settings key.
public struct AnySettings: Sendable {
    let id: String
    let `default`: SettingsValue
    init<Value>(_ key: Settings<Value>) where Value: SettingsValue {
        self.id = key.id
        self.default = key.default
    }
}

// MARK: Errors
// ============================================================================

/// An application error.
public enum AppError: Error {
    /// An error related to HealthKit operations.
    case healthKit(HealthKitError)
    /// An error related to data storage operations (e.g., SwiftData).
    case data(String, Error? = nil)
    /// An error related to analytics operations.
    case analytics(String, Error? = nil)
    /// An error related to unit conversion or localization.
    case localization(String, Error? = nil)
    /// A generic runtime error with a descriptive message.
    case runtimeError(String, Error? = nil)
}

/// Specific errors related to HealthKit operations.
public enum HealthKitError: Error {
    case authorizationFailed(String)
    case queryFailed(String)
    case saveFailed(String)
    case deleteFailed(String)
    case unexpectedError(String)
}
