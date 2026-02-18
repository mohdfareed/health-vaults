import Foundation
import SwiftData

// TODO: Add food name

// MARK: - Macro Nutrients
// ============================================================================

/// Macronutrient types for categorization and display.
public enum MacroType: String, CaseIterable, Sendable {
    case protein = "protein"
    case carbs = "carbs"
    case fat = "fat"
}

/// Macronutrient breakdown for calorie entries.
public struct CalorieMacros: Codable, Hashable, Sendable {
    /// Protein content in grams.
    public var protein: Double?
    /// Fat content in grams.
    public var fat: Double?
    /// Carbohydrate content in grams.
    public var carbs: Double?

    public init(p: Double? = nil, f: Double? = nil, c: Double? = nil) {
        self.protein = p
        self.fat = f
        self.carbs = c
    }
}

// MARK: - Dietary Calorie Model
// ============================================================================

/// Represents dietary calorie intake with optional macro breakdown.
@Observable public final class DietaryCalorie: HealthData, @unchecked Sendable {
    public let id: UUID
    public let source: DataSource
    public var date: Date

    /// Energy value in kilocalories.
    public var calories: Double
    /// The primary numeric value for aggregation.
    public var value: Double { calories }
    /// Optional macronutrient breakdown.
    public var macros: CalorieMacros?
    /// Alcohol content in standard drinks.
    public var alcohol: Double?

    public init(
        _ value: Double,
        macros: CalorieMacros? = nil, alcohol: Double? = nil,
        id: UUID = UUID(),
        source: DataSource = .app,
        date: Date = Date()
    ) {
        self.calories = value
        self.macros = macros
        self.alcohol = alcohol

        self.id = id
        self.source = source
        self.date = date
    }

    public convenience init() {
        self.init(0)
    }
}
