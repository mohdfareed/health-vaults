import Foundation

// MARK: Definitions
// ============================================================================

extension UnitDefinition where D == UnitEnergy {
    /// Generic calorie unit definition (kilocalories as base).
    public static let calorie = UnitDefinition<UnitEnergy>(
        .kilocalories,
        usage: .food,
        healthKitType: .dietaryCalories,
    )
}

extension UnitDefinition where D == UnitMass {
    /// Protein unit definition (grams as base).
    public static let macro = UnitDefinition<UnitMass>(
        .grams,
        usage: .asProvided,
        healthKitType: .protein,
    )

    /// Weight unit definition (kilograms as base).
    public static let weight = UnitDefinition<UnitMass>(
        .kilograms, alts: [.pounds, .stones],
        usage: .personWeight,
        healthKitType: .bodyMass,
    )

    /// Percentage unit definition (percent as base).
    public static let percentage = UnitDefinition<UnitMass>(
        .percent,
        usage: .asProvided,
    )

    /// Body fat percentage definition (fraction shown as percent).
    public static let bodyFat = UnitDefinition<UnitMass>(
        .percent,
        usage: .asProvided,
        healthKitType: .bodyFatPercentage,
    )
}

extension UnitDefinition where D == UnitVolume {
    /// Alcohol contents unit definition (standard drink as base).
    public static let alcohol = UnitDefinition<UnitVolume>(
        .standardDrink,
        alts: [.milliliters, .fluidOunces, .standardDrink],
        usage: .asProvided,
        healthKitType: .alcohol,
    )
}

// MARK: Units
// ============================================================================

extension UnitMass {
    /// A unit for representing percentages, based on grams.
    public static var percent: UnitMass {
        return UnitMass(
            symbol: "%",
            // 100 percent = 1 gram
            converter: UnitConverterLinear(coefficient: 0.01)
        )
    }
}

extension UnitVolume {
    /// Standard drink unit definition (17.7 milliliters of pure alcohol).
    public static let standardDrink = UnitVolume(
        symbol: "drinks",
        converter: UnitConverterLinear(coefficient: 0.0177)  // liters
    )
}

extension UnitDuration {
    /// A unit for representing days, based on seconds.
    public static var days: UnitDuration {
        return UnitDuration(
            symbol: "d",
            // 60 seconds * 60 minutes * 24 hours
            converter: UnitConverterLinear(coefficient: 60 * 60 * 24)
        )
    }

}
