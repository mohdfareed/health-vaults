import Foundation
import SwiftUI
import WidgetKit

// MARK: - Budget Analytics Service
// ============================================================================

/// Core budget calculations using 7-day EWMA and maintenance estimation.
/// Implements the mathematical specification from README.md.
public struct BudgetService: Sendable {
    public let calories: DataAnalyticsService
    public let weight: WeightAnalyticsService

    /// User-defined daily calorie adjustment (kcal).
    public let adjustment: Double?
    /// First day of weekly budget cycle (1=Sunday, 2=Monday, etc.).
    public let firstWeekday: Int

    /// Days remaining in current weekly budget cycle.
    public var daysLeft: Int {
        let cal = Calendar.autoupdatingCurrent
        let date = calories.currentIntakeDateRange?.from ?? Date()
        let nextWeek = date.next(firstWeekday, using: cal)!
        let daysLeft = date.distance(to: nextWeek, in: .day, using: cal)!
        return daysLeft
    }

    /// Base daily budget: B = M + A (kcal).
    /// Uses maintenance estimate plus user adjustment.
    public var baseBudget: Double? {
        guard let weight = weight.maintenance else { return adjustment }
        guard let adjustment = adjustment else { return weight }
        return weight + adjustment
    }

    /// Daily calorie credit: C = B - S (kcal).
    /// Positive indicates under-budget, negative indicates over-budget.
    public var credit: Double? {
        guard let baseBudget = baseBudget else { return nil }
        return baseBudget - (calories.smoothedIntake ?? 0)
    }

    /// Adjusted daily budget: B' = B + C/D (kcal).
    /// Distributes weekly credit across remaining days in cycle.
    public var budget: Double? {
        guard let baseBudget = baseBudget else { return nil }
        guard let credit = credit else { return baseBudget }
        return baseBudget + (credit / Double(daysLeft))
    }

    /// Remaining budget for today: R = B' - I (kcal).
    public var remaining: Double? {
        guard let budget = budget else { return nil }
        return budget - (calories.currentIntake ?? 0)
    }

    /// Whether maintenance estimate has sufficient data (≥1 week).
    public var isValid: Bool {
        guard let range = calories.intakeDateRange else { return false }

        return range.from.distance(
            to: range.to, in: .weekOfYear, using: .autoupdatingCurrent
        ) ?? 0 >= 1
    }
}
