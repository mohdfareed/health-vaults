import Foundation
import HealthKit

// MARK: Supported Types
// ============================================================================

public enum HealthKitDataType: CaseIterable, Sendable {
    case bodyMass
    case dietaryCalories
    case protein, carbs, fat, alcohol

    var sampleType: HKSampleType { quantityType }

    var quantityType: HKQuantityType {
        switch self {
        case .bodyMass: HKQuantityType(.bodyMass)
        case .dietaryCalories: HKQuantityType(.dietaryEnergyConsumed)
        case .protein: HKQuantityType(.dietaryProtein)
        case .carbs: HKQuantityType(.dietaryCarbohydrates)
        case .fat: HKQuantityType(.dietaryFatTotal)
        case .alcohol: HKQuantityType(.numberOfAlcoholicBeverages)
        }
    }
}

// MARK: Extensions
// ============================================================================

extension HKSource {
    /// Returns the data source of the HealthKit source.
    var dataSource: DataSource {
        switch bundleIdentifier.lowercased() {
        case let id where id.hasSuffix(AppID.lowercased()):
            return .app
        case let id where id.hasPrefix("com.apple.health"):
            return .healthKit
        case let id where id.hasPrefix("com.apple.shortcuts"):
            return .shortcuts
        case let id where id.hasSuffix("FoodNoms".lowercased()):
            return .foodNoms

        default:
            switch name.lowercased() {
            case AppID.lowercased():
                return .app
            case "Health".lowercased():
                return .healthKit
            case "Shortcuts".lowercased():
                return .shortcuts
            case "FoodNoms".lowercased():
                return .foodNoms
            default:
                return .other(name)
            }
        }
    }
}

extension [HKQuantitySample] {
    /// Sums the quantities in the array using the specified unit.
    func sum(as unit: HKUnit) -> Double? {
        guard !isEmpty else { return nil }
        return reduce(0) { $0 + $1.quantity.doubleValue(for: unit) }
    }
}
