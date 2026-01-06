import Foundation
import SwiftUI
import WidgetKit

// MARK: - Budget Analytics Service
// ============================================================================

/// Core budget calculations using cumulative weekly credit and maintenance estimation.
/// Implements the mathematical specification from README.md.
public struct BudgetService: Sendable {
    public let calories: DataAnalyticsService
    public let weight: WeightAnalyticsService

    /// Actual daily intake from week start to yesterday (for credit calculation).
    public let weekIntakes: [Date: Double]

    /// User-defined daily calorie adjustment (kcal).
    public let adjustment: Double?
    /// First day of weekly budget cycle (1=Sunday, 2=Monday, etc.).
    public let firstWeekday: Int

    /// The current date for calculations.
    private var currentDate: Date {
        calories.currentIntakeDateRange?.from ?? Date()
    }

    /// Start of the current week based on firstWeekday setting.
    private var weekStart: Date? {
        currentDate.previous(firstWeekday, using: .autoupdatingCurrent)
    }

    /// Days elapsed from week start to yesterday (days with credit impact).
    /// Returns 0 if today is the first day of the week.
    public var daysElapsed: Int {
        guard let weekStart = weekStart else { return 0 }
        let yesterday = currentDate.adding(-1, .day, using: .autoupdatingCurrent)
        guard let yesterday = yesterday else { return 0 }

        // If yesterday is before week start, no days have elapsed yet
        if yesterday < weekStart { return 0 }

        return weekStart.distance(to: yesterday, in: .day, using: .autoupdatingCurrent)! + 1
    }

    /// Days remaining in current weekly budget cycle (including today).
    public var daysLeft: Int {
        let cal = Calendar.autoupdatingCurrent
        let nextWeek = currentDate.next(firstWeekday, using: cal)!
        let daysLeft = currentDate.distance(to: nextWeek, in: .day, using: cal)!
        return daysLeft
    }

    /// Base daily budget: B = M + A (kcal).
    /// Uses maintenance estimate plus user adjustment.
    public var baseBudget: Double? {
        guard let weight = weight.maintenance else { return adjustment }
        guard let adjustment = adjustment else { return weight }
        return weight + adjustment
    }

    /// Weekly calorie credit: C = (B × days_elapsed) - actual_intake (kcal).
    /// Positive indicates under-budget (banked calories), negative indicates over-budget (debt).
    /// Returns nil when maintenance isn't calibrated.
    public var credit: Double? {
        guard weight.isValid else { return nil }
        guard let baseBudget = baseBudget else { return nil }

        // If no days have elapsed yet (today is first day of week), credit is 0
        guard daysElapsed > 0 else { return 0 }

        // Sum actual intake from week start to yesterday
        let actualIntake = weekIntakes.values.sum()

        // Credit = what you should have eaten - what you actually ate
        return (baseBudget * Double(daysElapsed)) - actualIntake
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
