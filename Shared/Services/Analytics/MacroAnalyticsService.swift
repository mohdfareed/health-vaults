import Foundation
import SwiftUI
import WidgetKit

// MARK: Budget Service
// ============================================================================

public struct MacrosAnalyticsService: Sendable {
    // MARK: - Types

    /// Represents the different macro nutrients for ring display
    public typealias MacroRing = MacroType

    // MARK: - Properties

    public let calories: BudgetService?
    public let protein: DataAnalyticsService
    public let carbs: DataAnalyticsService
    public let fat: DataAnalyticsService

    /// User-defined budget adjustment (kcal)
    public let adjustments: CalorieMacros?

    /// The base daily budget in grams: derived from calorie budget and macro percentages.
    /// Formula: (CalorieBudget × MacroPercent / 100) / CaloriesPerGram
    /// Where CaloriesPerGram is 4 for protein/carbs, 9 for fat.
    public var budgets: CalorieMacros? {
        guard let adjustments = adjustments else { return nil }
        guard let budget = calories?.baseBudget else { return nil }

        // Calculate the macro budgets based on the adjustments (percentages)
        let macroCalories = CalorieMacros(
            p: adjustments.protein.map { budget * $0 / 100 },
            f: adjustments.fat.map { budget * $0 / 100 },
            c: adjustments.carbs.map { budget * $0 / 100 }
        )

        // Convert calories to grams
        return CalorieMacros(
            p: macroCalories.protein.map { $0 / 4 },
            f: macroCalories.fat.map { $0 / 9 },
            c: macroCalories.carbs.map { $0 / 4 }
        )
    }

    /// Remaining budget for today: Budget - Today's Intake (grams).
    /// Unlike calories, macros don't use weekly credit banking.
    public var remaining: CalorieMacros? {
        guard let budget = budgets else { return nil }
        return CalorieMacros(
            p: budget.protein.map { $0 - (protein.currentIntake ?? 0) },
            f: budget.fat.map { $0 - (fat.currentIntake ?? 0) },
            c: budget.carbs.map { $0 - (carbs.currentIntake ?? 0) }
        )
    }
}
