import Foundation

// MARK: - Budget Analytics Service
// ============================================================================

/// Core budget calculations using week-aligned credit and weekly repayment schedule.
public struct BudgetService: Sendable, Codable {
    public let weight: MaintenanceService

    /// Actual daily intake for the current week (week start to yesterday, for credit calculation).
    public let weekIntakes: [Date: Double]

    /// User-defined daily calorie adjustment (kcal).
    public let adjustment: Double?
    /// First day of weekly budget cycle (1=Sunday, 2=Monday, etc.).
    public let firstWeekday: Int
    /// The reference date for calculations (typically today).
    public let currentDate: Date

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

    /// Week-aligned calorie credit: C = (B x daysElapsedThisWeek) - thisWeekIntake (kcal).
    /// Positive indicates under-budget (banked calories), negative indicates over-budget (debt).
    /// Resets cleanly on firstWeekday. Only counts days with logged data — missing days don't inflate credit.
    public var credit: Double {
        let actualIntake = weekIntakes.values.sum()
        let daysLogged = Double(weekIntakes.count)
        // Credit = what you should have eaten - what you actually ate (for logged days only)
        return (baseBudget * daysLogged) - actualIntake
    }

    /// Daily credit adjustment, capped to prevent extreme budgets.
    /// Uses `MaxDailyAdjustment` (±500 kcal) from Config.
    public var dailyAdjustment: Double {
        let raw = credit / Double(daysLeft)
        return max(-MaxDailyAdjustment, min(MaxDailyAdjustment, raw))
    }

    /// Whether the weekly credit was too large to spread evenly within the cap.
    /// True when the raw per-day adjustment exceeded ±`MaxDailyAdjustment`.
    /// The displayed budget is lower or higher than the ideal redistribution.
    public var isAdjustmentClamped: Bool {
        let raw = credit / Double(daysLeft)
        return abs(raw) > MaxDailyAdjustment
    }

    /// Adjusted daily budget: B' = clamp(B + clamp(C/daysLeft), MinDailyBudget, MaxDailyBudget) (kcal).
    /// Distributes credit over remaining days with safety cap, then enforces absolute floor/ceiling.
    public var budget: Double {
        return max(MinDailyBudget, min(MaxDailyBudget, baseBudget + dailyAdjustment))
    }

    /// Whether the absolute floor (`MinDailyBudget`) or ceiling (`MaxDailyBudget`) was applied.
    /// When true, the displayed budget is not the calculated value — it has been constrained
    /// to a biologically safe range. The maintenance estimate may be unreliable.
    public var isBudgetClamped: Bool {
        let raw = baseBudget + dailyAdjustment
        return raw < MinDailyBudget || raw > MaxDailyBudget
    }

    /// Remaining budget for today: R = B' - I (kcal).
    public var remaining: Double {
        return budget - (weight.calories.currentIntake ?? 0)
    }

    /// Unified confidence factor (0-1) from weight data quality.
    public var confidence: Double {
        return weight.confidence
    }

    /// Whether budget calculations have sufficient data to be useful.
    /// With independent component blending, either weight OR calorie data is sufficient:
    /// calorie-only → maintenance ≈ intake (assumes stable weight)
    /// weight-only → maintenance adjusts baseline by weight trend
    public var isValid: Bool {
        return weight.isValid
    }
}
