import HealthKit

// MARK: Units Service
// ============================================================================

extension HealthKitService {
    /// Returns the preferred unit for a single quantity type.
    @MainActor
    public func preferredUnit(for quantityType: HKQuantityType?) -> Unit? {
        guard let quantityType = quantityType else { return nil }
        return Self.unitsCache[quantityType]
    }

    /// Sets up the HealthKit units. Must be called once on initialization.
    internal func setupUnits() async {
        await self.loadUnits()  // Load initial units

        // Observe changes to user preferences and reload units
        unitObserverToken = NotificationCenter.default.addObserver(
            forName: .HKUserPreferencesDidChange,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.loadUnits() }
        }
    }

    private func loadUnits() async {
        var units: [HKQuantityType: HKUnit] = [:]

        do {
            units = try await store.preferredUnits(
                for: Set(
                    HealthKitDataType.allCases.compactMap { $0.quantityType }
                )
            )
        } catch {
            let error = error.localizedDescription
            logger.error("Failed to load preferred units: \(error)")
            return
        }

        await MainActor.run {
            // Thread-safe cache update - replace entire cache atomically
            var newCache: [HKQuantityType: Unit] = [:]
            for (type, unit) in units {
                if let measurementUnit = unit.measurementUnit {
                    newCache[type] = measurementUnit
                }
            }
            Self.unitsCache = newCache
        }
    }
}

// MARK: Unit Conversion
// ============================================================================

extension HKUnit {
    internal var measurementUnit: Unit? {
        switch self {
        // Energy units
        case .kilocalorie():
            return UnitEnergy.kilocalories
        case .largeCalorie():
            return UnitEnergy.kilocalories
        case .smallCalorie():
            return UnitEnergy.calories
        case .joule():
            return UnitEnergy.joules

        // Mass units
        case .gram():
            return UnitMass.grams
        case .pound():
            return UnitMass.pounds
        case .ounce():
            return UnitMass.ounces
        case .stone():
            return UnitMass.stones
        case .gramUnit(with: .kilo):
            return UnitMass.kilograms

        // Duration units
        case .second():
            return UnitDuration.seconds
        case .minute():
            return UnitDuration.minutes
        case .hour():
            return UnitDuration.hours
        case .day():
            return UnitDuration.days

        // Volume units
        case .liter():
            return UnitVolume.liters
        case .literUnit(with: .milli):
            return UnitVolume.milliliters
        case .fluidOunceImperial():
            return UnitVolume.imperialFluidOunces
        case .fluidOunceUS():
            return UnitVolume.fluidOunces

        case .count():
            return nil  // Count is not mapped to a Measurement Unit
        default:
            // Fallback for unmapped units - create a custom unit
            AppLogger.new(for: HealthKitService.self).warning(
                "HKUnit \(self) not mapped to a Measurement Unit."
            )
            return nil
        }
    }
}

extension HealthKitDataType {
    public var baseUnit: HKUnit {
        switch self {
        case .dietaryCalories: .kilocalorie()
        case .protein, .carbs, .fat: .gram()
        case .bodyMass: .gramUnit(with: .kilo)
        case .alcohol: .count()
        }
    }
}
