import Foundation

// MARK: - Budget Analytics Service
// ============================================================================

/// Core budget calculations using rolling 7-day credit and weekly repayment schedule.
public struct BudgetService: Sendable, Codable {
    public let calories: IntakeAnalyticsService
    public let weight: MaintenanceService

    /// Actual daily intake for the last 7 days (for rolling credit calculation).
    public let rollingIntakes: [Date: Double]

    /// User-defined daily calorie adjustment (kcal).
    public let adjustment: Double?
    /// First day of weekly budget cycle (1=Sunday, 2=Monday, etc.).
    public let firstWeekday: Int
    /// The reference date for calculations (typically today).
    public let currentDate: Date

    /// Maximum daily adjustment from credit (kcal). Prevents extreme budgets.
    private let maxDailyAdjustment: Double = 500

    /// Days remaining until next firstWeekday (including today).
    public var daysLeft: Int {
        let cal = Calendar.autoupdatingCurrent
        guard let nextWeek = currentDate.next(firstWeekday, using: cal),
            let days = currentDate.distance(to: nextWeek, in: .day, using: cal)
        else { return 7 }
        return max(1, days)  // At least 1 to avoid division by zero
    }

    /// Base daily budget: B = M + A (kcal).
    /// Uses maintenance estimate plus user adjustment.
    public var baseBudget: Double {
        guard let adjustment = adjustment else { return weight.maintenance }
        return weight.maintenance + adjustment
    }

    /// Rolling 7-day calorie credit: C = (B × daysLogged) - actualIntake (kcal).
    /// Positive indicates under-budget (banked calories), negative indicates over-budget (debt).
    /// Only counts days with logged data - missing days don't inflate credit.
    public var credit: Double {
        let actualIntake = rollingIntakes.values.sum()
        let daysLogged = Double(rollingIntakes.count)
        // Credit = what you should have eaten - what you actually ate (for logged days only)
        return (baseBudget * daysLogged) - actualIntake
    }

    /// Daily credit adjustment, capped to prevent extreme budgets.
    public var dailyAdjustment: Double {
        let raw = credit / Double(daysLeft)
        return max(-maxDailyAdjustment, min(maxDailyAdjustment, raw))
    }

    /// Adjusted daily budget: B' = B + clamp(C/daysLeft) (kcal).
    /// Distributes credit over remaining days until next firstWeekday, with safety cap.
    public var budget: Double {
        return baseBudget + dailyAdjustment
    }

    /// Remaining budget for today: R = B' - I (kcal).
    public var remaining: Double {
        return budget - (calories.currentIntake ?? 0)
    }

    /// Unified confidence factor (0-1) combining weight and calorie data quality.
    /// Uses the higher confidence since each component blends independently — having
    /// good data in either source produces a useful budget estimate.
    public var confidence: Double {
        return max(weight.confidence, calories.confidence)
    }

    /// Whether budget calculations have sufficient data to be useful.
    /// With independent component blending, either weight OR calorie data is sufficient:
    /// calorie-only → maintenance ≈ intake (assumes stable weight)
    /// weight-only → maintenance adjusts baseline by weight trend
    public var isValid: Bool {
        return weight.isValid
    }
}
