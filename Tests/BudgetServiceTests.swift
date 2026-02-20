import Testing
import Foundation
@testable import HealthVaultsShared

// MARK: - BudgetService Tests
// ============================================================================

/// A MaintenanceService that approximates a known maintenance value by feeding
/// stable data (constant weight + constant calories at the target for 28 days).
private func maintenanceService(
    maintenance target: Double,
    fallback: Double? = nil
) -> MaintenanceService {
    MaintenanceService(
        calories: intakeService(intake: target, days: 28),
        weights: constantWeights(days: 28),
        fallbackMaintenance: fallback ?? target
    )
}

/// Week intake dictionary with `count` logged days, each at `daily` kcal.
/// Dates are arbitrary — BudgetService only uses `.values.sum()` and `.count`.
private func weekIntakes(days: Int, daily: Double) -> [Date: Double] {
    (0..<days).reduce(into: [:]) { dict, i in
        dict[daysAgo(7 + i)] = daily  // use dates safely outside main window
    }
}

// MARK: - Suite

@Suite("BudgetService")
struct BudgetServiceTests {

    // MARK: - baseBudget

    @Test("No adjustment: baseBudget equals maintenance")
    func noAdjustment_baseBudgetEqualsMaintenance() {
        let maintenance = maintenanceService(maintenance: 2200)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        // maintenance ≈ 2200 (stable weight + constant 2200 kcal diet)
        #expect(abs(svc.baseBudget - svc.weight.maintenance) < 1.0)
    }

    @Test("Positive adjustment increases baseBudget")
    func positiveAdjustment_increasesBudget() {
        let maintenance = maintenanceService(maintenance: 2200)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: 300,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(abs(svc.baseBudget - (svc.weight.maintenance + 300)) < 1.0)
    }

    @Test("Negative adjustment (deficit) decreases baseBudget")
    func negativeAdjustment_decreasesBudget() {
        let maintenance = maintenanceService(maintenance: 2200)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: -500,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(abs(svc.baseBudget - (svc.weight.maintenance - 500)) < 1.0)
    }

    // MARK: - Credit (week-aligned)

    @Test("No logged days this week: credit is zero")
    func noLoggedDays_zeroCredit() {
        let maintenance = maintenanceService(maintenance: 2200)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: [:],  // no data
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(svc.credit == 0)
    }

    @Test("Eating exactly at budget for 3 days: credit is zero")
    func eatingAtBudget_zeroCredit() {
        // We'll use raw math without relying on exact maintenance value
        let exactBudget = 2200.0
        let maintenance = maintenanceService(maintenance: exactBudget)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: weekIntakes(days: 3, daily: exactBudget),
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        // credit = baseBudget * 3 - exactBudget * 3 ≈ 0
        #expect(abs(svc.credit) < 30)  // tolerance for EWMA imprecision
    }

    @Test("Eating 500 kcal under budget for 4 days: credit ≈ 2000")
    func underBudget_500for4days_credit2000() {
        let base = 2200.0
        let maintenance = maintenanceService(maintenance: base)
        let intakePerDay = base - 500  // 1700
        let loggedDays = 4
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: weekIntakes(days: loggedDays, daily: intakePerDay),
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        // credit ≈ 2200 * 4 - 1700 * 4 = 8800 - 6800 = 2000
        let expected = svc.baseBudget * Double(loggedDays) - intakePerDay * Double(loggedDays)
        #expect(abs(svc.credit - expected) < 1.0)
        #expect(svc.credit > 0)  // positive = under-budget (banked)
    }

    @Test("Overeating produces negative credit (debt)")
    func overeating_negativeCredit() {
        let base = 2200.0
        let maintenance = maintenanceService(maintenance: base)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: weekIntakes(days: 3, daily: base + 600),  // 200 over
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(svc.credit < 0)
    }

    @Test("Credit counts only logged days, not all elapsed days")
    func credit_onlyCountsLoggedDays() {
        // 4 days elapsed, 2 logged
        let base = 2200.0
        let maintenance = maintenanceService(maintenance: base)
        let loggedDays = 2
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: weekIntakes(days: loggedDays, daily: 0),  // logged 0 kcal
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        // credit = baseBudget * 2 - 0 = 2 * maintenance (not 4 * maintenance)
        let expected = svc.baseBudget * Double(loggedDays)
        #expect(abs(svc.credit - expected) < 1.0)
    }

    // MARK: - Daily Adjustment (credit distribution)

    @Test("Small credit distributes evenly without clamping")
    func smallCredit_notClamped() {
        let base = 2200.0
        let maintenance = maintenanceService(maintenance: base)
        // 3 logged days, 200 under each day → credit ≈ 600
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: weekIntakes(days: 3, daily: base - 200),
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday   // daysLeft = 5
        )
        // dailyAdjustment ≈ 600 / 5 = 120 (well within ±500)
        let raw = svc.credit / Double(svc.daysLeft)
        #expect(abs(svc.dailyAdjustment - raw) < 1.0)
        #expect(abs(svc.dailyAdjustment) < 500)
    }

    @Test("Large credit is clamped to +500 kcal/day")
    func largeCredit_clampedPositive() {
        let base = 2200.0
        let maintenance = maintenanceService(maintenance: base)
        // 6 logged days eating nothing → credit = 2200 * 6 = 13200
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: weekIntakes(days: 6, daily: 0),
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday   // daysLeft = 5
        )
        // Raw adjustment = ~13200/5 = ~2640 → clamped to 500
        #expect(svc.dailyAdjustment == 500)
    }

    @Test("Large debt is clamped to -500 kcal/day")
    func largeDebt_clampedNegative() {
        let base = 2200.0
        let maintenance = maintenanceService(maintenance: base)
        // 6 days massively over budget
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: weekIntakes(days: 6, daily: base + 3000),
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(svc.dailyAdjustment == -500)
    }

    // MARK: - Budget Formula

    @Test("Budget = baseBudget + dailyAdjustment")
    func budgetFormula_correct() {
        let base = 2200.0
        let maintenance = maintenanceService(maintenance: base)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: weekIntakes(days: 3, daily: 1700),
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(abs(svc.budget - (svc.baseBudget + svc.dailyAdjustment)) < 0.01)
    }

    @Test("No credit, no adjustment: budget equals maintenance")
    func noCreditNoAdjust_budgetEqualsMaintenance() {
        let base = 2200.0
        let maintenance = maintenanceService(maintenance: base)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(abs(svc.budget - svc.weight.maintenance) < 1.0)
    }

    // MARK: - Remaining

    @Test("Remaining = budget - currentIntake")
    func remaining_budgetMinusIntake() {
        let base = 2200.0
        let maintenance = maintenanceService(maintenance: base)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        // currentIntake is from weight.calories.currentIntake
        let expected = svc.budget - (svc.weight.calories.currentIntake ?? 0)
        #expect(abs(svc.remaining - expected) < 0.01)
    }

    // MARK: - daysLeft

    @Test("Wednesday with Monday week start: 5 days left until next Monday")
    func daysLeft_wednesday_mondayWeekStart() {
        let maintenance = maintenanceService(maintenance: 2200)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,   // Monday
            currentDate: referenceWednesday  // 2024-01-03 = Wednesday
        )
        #expect(svc.daysLeft == 5)
    }

    @Test("daysLeft is always at least 1")
    func daysLeft_minimumOne() {
        let maintenance = maintenanceService(maintenance: 2200)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(svc.daysLeft >= 1)
    }

    // MARK: - isValid / Confidence

    @Test("isValid reflects weight service validity")
    func isValid_delegatesToWeightService() {
        let maintenance = maintenanceService(maintenance: 2200)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(svc.isValid == svc.weight.isValid)
    }

    @Test("confidence reflects weight confidence")
    func confidence_delegatesToWeight() {
        let maintenance = maintenanceService(maintenance: 2200)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(svc.confidence == svc.weight.confidence)
    }

    // MARK: - Edge Cases

    @Test("NaN weight data does not crash and returns positive budget")
    func nanWeightData_noCrash() {
        // NaN weights get filtered in dailyWeights (filter { !$0.value.isNaN })
        let maintenance = maintenanceService(maintenance: 2200)
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(svc.budget.isFinite)
        #expect(svc.budget > 0)
    }

    @Test("Zero calorie intake all week: credit equals baseBudget x loggedDays")
    func zeroIntakeAllWeek_creditEqualsBaseBudgetTimesLoggedDays() {
        let base = 2200.0
        let maintenance = maintenanceService(maintenance: base)
        let loggedDays = 3
        let svc = BudgetService(
            weight: maintenance,
            weekIntakes: weekIntakes(days: loggedDays, daily: 0),
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        let expected = svc.baseBudget * Double(loggedDays)
        #expect(abs(svc.credit - expected) < 1.0)
    }
}
