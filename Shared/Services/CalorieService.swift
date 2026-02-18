import Foundation

// MARK: Macro Calculations
// ============================================================================

extension DietaryCalorie {
    /// The amount of calories calculated from the macros or alcohol content.
    /// Returns `nil` when all macro/alcohol inputs are zero (nothing to compute from).
    func calculatedCalories() -> Double? {
        let p = self.macros?.protein ?? 0
        let f = self.macros?.fat ?? 0
        let c = self.macros?.carbs ?? 0
        let a = self.alcohol ?? 0
        guard p + f + c + a > 0 else { return nil }
        return ((p + c) * 4) + (f * 9) + (a * 98)
    }

    /// The amount of protein calculated from the calories, carbs, and fat.
    func calculatedProtein() -> Double? {
        let fat = self.macros?.fat ?? 0
        let carbs = self.macros?.carbs ?? 0
        let alcohol = self.alcohol ?? 0

        let fatCalories = fat * 9
        let carbsCalories = carbs * 4
        let alcoholCalories = alcohol * 98

        let macros = fatCalories + carbsCalories + alcoholCalories
        return Double(self.calories - macros) / 4
    }

    /// The amount of carbs calculated from the calories, protein, and fat.
    func calculatedCarbs() -> Double? {
        let protein = self.macros?.protein ?? 0
        let fat = self.macros?.fat ?? 0
        let alcohol = self.alcohol ?? 0

        let proteinCalories = protein * 4
        let fatCalories = fat * 9
        let alcoholCalories = alcohol * 98

        let macros = proteinCalories + fatCalories + alcoholCalories
        return Double(self.calories - macros) / 4
    }

    /// The amount of fat calculated from the calories, protein, and carbs.
    func calculatedFat() -> Double? {
        let protein = self.macros?.protein ?? 0
        let carbs = self.macros?.carbs ?? 0
        let alcohol = self.alcohol ?? 0

        let proteinCalories = protein * 4
        let carbsCalories = carbs * 4
        let alcoholCalories = alcohol * 98

        let macros = proteinCalories + carbsCalories + alcoholCalories
        return Double(self.calories - macros) / 9
    }

    /// The amount of alcohol calculated from the calories.
    func calculatedAlcohol() -> Double? {
        let protein = self.macros?.protein ?? 0
        let fat = self.macros?.fat ?? 0
        let carbs = self.macros?.carbs ?? 0

        let proteinCalories = protein * 4
        let fatCalories = fat * 9
        let carbsCalories = carbs * 4

        let macros = proteinCalories + fatCalories + carbsCalories
        return Double(self.calories - macros) / 98
    }
}
