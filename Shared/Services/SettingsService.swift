import SwiftData
import SwiftUI

// MARK: Primitive Types
// ============================================================================

// Types natively supported by `UserDefaults`.
extension String: SettingsValue {}
extension Bool: SettingsValue {}
extension Int: SettingsValue {}
extension Double: SettingsValue {}
extension URL: SettingsValue {}
extension Date: SettingsValue {}
extension Data: SettingsValue {}
extension PersistentIdentifier: SettingsValue {}
extension Optional: SettingsValue {}

// MARK: Supported Types
// ============================================================================

// App locale.
extension Weekday: SettingsValue {}
extension MeasurementSystem: SettingsValue, @retroactive RawRepresentable {
    public var rawValue: String { self.identifier }
    public init?(rawValue: String) { self.init(rawValue) }
}

// Model IDs.
extension UUID: SettingsValue, @retroactive RawRepresentable {
    public var rawValue: String { self.uuidString }
    public init?(rawValue: String) { self.init(uuidString: rawValue) }
}

// MARK: `AppStorage` Integration
// ============================================================================

extension AppStorage {
    // String =================================================================
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == String {
        self.init(wrappedValue: key.default, key.id, store: store)
    }
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == String? { self.init(key.id, store: store) }
    // Bool ===================================================================
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == Bool {
        self.init(wrappedValue: key.default, key.id, store: store)
    }
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == Bool? { self.init(key.id, store: store) }
    // Int ====================================================================
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == Int {
        self.init(wrappedValue: key.default, key.id, store: store)
    }
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == Int? { self.init(key.id, store: store) }
    // Double =================================================================
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == Double {
        self.init(wrappedValue: key.default, key.id, store: store)
    }
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == Double? { self.init(key.id, store: store) }
    // URL ====================================================================
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == URL {
        self.init(wrappedValue: key.default, key.id, store: store)
    }
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == URL? { self.init(key.id, store: store) }
    // Date ===================================================================
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == Date {
        self.init(wrappedValue: key.default, key.id, store: store)
    }
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == Date? { self.init(key.id, store: store) }
    // Data ===================================================================
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == Data {
        self.init(wrappedValue: key.default, key.id, store: store)
    }
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == Data? { self.init(key.id, store: store) }
    // PersistentIdentifier ===================================================
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == PersistentIdentifier {
        self.init(wrappedValue: key.default, key.id, store: store)
    }
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == PersistentIdentifier? { self.init(key.id, store: store) }
    // RawRepresentable | String ==============================================
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value: RawRepresentable, Value.RawValue == String {
        self.init(wrappedValue: key.default, key.id, store: store)
    }
    public init<R>(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == R?, R: RawRepresentable, R.RawValue == String {
        self.init(key.id, store: store)
    }
    // RawRepresentable | Int =================================================
    public init(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value: RawRepresentable, Value.RawValue == Int {
        self.init(wrappedValue: key.default, key.id, store: store)
    }
    public init<R>(_ key: Settings<Value>, store: UserDefaults? = nil)
    where Value == R?, R: RawRepresentable, R.RawValue == Int {
        self.init(key.id, store: store)
    }
}

// MARK: `UserDefaults` Integration
// ============================================================================

extension UserDefaults {
    // String =================================================================
    public func string(for key: Settings<String>) -> String {
        self.string(forKey: key.id) ?? key.default
    }
    public func string(for key: Settings<String?>) -> String? {
        self.string(forKey: key.id)
    }
    public func set(_ value: String?, for key: Settings<String>) {
        self.set(value, forKey: key.id)
    }
    // Bool ===================================================================
    public func bool(for key: Settings<Bool>) -> Bool {
        self.bool(forKey: key.id)
    }
    public func bool(for key: Settings<Bool?>) -> Bool? {
        self.object(forKey: key.id) as? Bool
    }
    public func set(_ value: Bool?, for key: Settings<Bool>) {
        self.set(value, forKey: key.id)
    }
    // Int ====================================================================
    public func int(for key: Settings<Int>) -> Int {
        self.integer(forKey: key.id)
    }
    public func int(for key: Settings<Int?>) -> Int? {
        self.object(forKey: key.id) as? Int
    }
    public func set(_ value: Int?, for key: Settings<Int>) {
        self.set(value, forKey: key.id)
    }
    // Double =================================================================
    public func double(for key: Settings<Double>) -> Double {
        self.double(forKey: key.id)
    }
    public func double(for key: Settings<Double?>) -> Double? {
        self.object(forKey: key.id) as? Double
    }
    public func set(_ value: Double?, for key: Settings<Double>) {
        self.set(value, forKey: key.id)
    }
    // URL ====================================================================
    public func url(for key: Settings<URL>) -> URL {
        self.url(forKey: key.id) ?? key.default
    }
    public func url(for key: Settings<URL?>) -> URL? {
        self.url(forKey: key.id)
    }
    public func set(_ value: URL?, for key: Settings<URL>) {
        self.set(value, forKey: key.id)
    }
    // Date ===================================================================
    public func date(for key: Settings<Date>) -> Date {
        self.object(forKey: key.id) as? Date ?? key.default
    }
    public func date(for key: Settings<Date?>) -> Date? {
        self.object(forKey: key.id) as? Date
    }
    public func set(_ value: Date?, for key: Settings<Date>) {
        self.set(value, forKey: key.id)
    }
    // Data ===================================================================
    public func data(for key: Settings<Data>) -> Data {
        self.data(forKey: key.id) ?? key.default
    }
    public func data(for key: Settings<Data?>) -> Data? {
        self.data(forKey: key.id)
    }
    public func set(_ value: Data?, for key: Settings<Data>) {
        self.set(value, forKey: key.id)
    }
    // PersistentIdentifier - Unsupported =====================================
    // RawRepresentable | String ==============================================
    public func rawRepresentable<R>(for key: Settings<R>) -> R
    where R: RawRepresentable, R.RawValue == String {
        guard let rawValue = self.string(forKey: key.id) else {
            return key.default
        }
        return R(rawValue: rawValue) ?? key.default
    }
    public func rawRepresentable<R>(for key: Settings<R?>) -> R?
    where R: RawRepresentable, R.RawValue == String {
        guard let rawValue = self.string(forKey: key.id) else { return nil }
        return R(rawValue: rawValue)
    }
    public func set<R>(_ value: R?, for key: Settings<R>)
    where R: RawRepresentable, R.RawValue == String {
        self.set(value?.rawValue, forKey: key.id)
    }
    // RawRepresentable | Int =================================================
    public func rawRepresentable<R>(for key: Settings<R>) -> R
    where R: RawRepresentable, R.RawValue == Int {
        guard let rawValue = self.object(forKey: key.id) as? Int else {
            return key.default
        }
        return R(rawValue: rawValue) ?? key.default
    }
    public func rawRepresentable<R>(for key: Settings<R?>) -> R?
    where R: RawRepresentable, R.RawValue == Int {
        guard let rawValue = self.object(forKey: key.id) as? Int else {
            return nil
        }
        return R(rawValue: rawValue)
    }
    public func set<R>(_ value: R?, for key: Settings<R>)
    where R: RawRepresentable, R.RawValue == Int {
        self.set(value?.rawValue, forKey: key.id)
    }
}
