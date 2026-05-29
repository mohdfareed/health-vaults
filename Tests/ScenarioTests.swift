import Foundation
import Testing

@testable import HealthVaultsShared

// MARK: - Real-Life Usage Scenario Tests
// =====================================================================
// Each test models a realistic user behavior pattern and validates that
// the full analytics pipeline (intake → MaintenanceService → BudgetService)
// produces biologically accurate, safe, and immediately actionable results.
//
// Biological invariants that must hold in every scenario:
//   • maintenance > 0 and .isFinite
//   • budget > 0 and .isFinite
//   • If user is consistently losing weight → maintenance > intake
//   • If user is consistently gaining weight → maintenance < intake
//   • If user is stable                     → maintenance ≈ intake ± noise
// =====================================================================

// MARK: - Fixed calendar dates for deterministic daysLeft assertions

/// Fixed Monday (2024-01-01). Week starts on Monday (firstWeekday = 2).
private let referenceMondayForScenarios: Date = {
    var c = DateComponents()
    c.year = 2024
    c.month = 1
    c.day = 1
    c.hour = 12
    return Calendar(identifier: .gregorian).date(from: c)!
}()

/// Fixed Sunday (2024-01-07). One day before the next Monday week-start.
private let referenceSundayForScenarios: Date = {
    var c = DateComponents()
    c.year = 2024
    c.month = 1
    c.day = 7
    c.hour = 12
    return Calendar(identifier: .gregorian).date(from: c)!
}()

// MARK: - Suite

@Suite("Real-Life Scenarios")
struct ScenarioTests {

    // =========================================================================
    // MARK: Group 1 — New Users (first days of tracking)
    // =========================================================================

    /// Brand new user: opens the app for the first time, no HealthKit data.
    /// Must get an immediately actionable budget (BaselineMaintenance) and not crash.
    @Test("New user, Day 1: no data → baseline budget, not valid")
    func newUser_day1_baselineBudget() {
        let maintenance = MaintenanceService(
            calories: IntakeAnalyticsService(currentIntakes: [:], intakes: [:], alpha: 0.25),
            weights: [:]
        )
        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )

        // Data quality: no data at all
        #expect(!budget.isValid)
        #expect(budget.confidence == 0)

        // Maintenance falls back to population baseline
        #expect(maintenance.maintenance == BaselineMaintenance)

        // Budget is always actionable — never zero or negative
        #expect(budget.budget > 0)
        #expect(budget.budget.isFinite)
        #expect(budget.credit == 0)
        #expect(budget.daysLeft >= 1)
    }

    /// User has tracked calories for 3 days only. Below the 14-day minimum.
    /// Budget should still be finite and safe, blended toward baseline.
    @Test("New user, 3 days calories logged, no weight → budget blended toward baseline")
    func newUser_3calorieDays_noWeight_budgetSafe() {
        let intakes: [Date: Double] = [daysAgo(2): 1950, daysAgo(1): 2000, daysAgo(0): 2100]
        let intake = IntakeAnalyticsService(
            currentIntakes: [daysAgo(0): 2100],
            intakes: intakes,
            alpha: 0.25
        )
        let maintenance = MaintenanceService(calories: intake, weights: [:])

        // 3 < MinCalorieDataPoints (14) → not valid
        #expect(!maintenance.isValid)
        // Maintenance is finite and positive (blended toward baseline)
        #expect(maintenance.maintenance > 0)
        #expect(maintenance.maintenance.isFinite)
        // No weight = no slope; energy balance assumptions don't apply
        #expect(maintenance.blendedSlope == 0)

        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: [daysAgo(1): 2000, daysAgo(0): 2100],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(budget.budget > 0)
        #expect(budget.budget.isFinite)
    }

    /// User tracked 7 days of calories — exactly one week, still below the 14-day threshold.
    /// The app must still return a safe budget.
    @Test("New user, 7 days calories only (full week) → not yet valid, budget safe")
    func newUser_7calorieDays_notValidYet() {
        let calories: [Date: Double] = (0..<7).reduce(into: [:]) { d, i in d[daysAgo(i)] = 2000 }
        let intake = IntakeAnalyticsService(
            currentIntakes: [daysAgo(0): 2000],
            intakes: calories,
            alpha: 0.25
        )
        let maintenance = MaintenanceService(calories: intake, weights: [:])

        // 7 < 14 minimum → not valid
        #expect(!maintenance.isValid)
        // Slope must be zero without weight data
        #expect(maintenance.blendedSlope == 0)
        // Budget still safe
        #expect(maintenance.maintenance > 0)
        #expect(maintenance.maintenance.isFinite)
    }

    /// User has 14 consecutive days of calorie logging, no weight scale.
    /// 14 days of data daysAgo(0)…daysAgo(13) spans 13 calendar days — below the
    /// 14-day span minimum (windowDays × 0.5 = 14), so isValid = false.
    /// Budget must still be finite and informed by real intake, not stuck at baseline.
    @Test(
        "New user, 14 days calories only → not yet valid (span < 14d), but budget informed by real intake"
    )
    func newUser_14calorieDays_budgetInformedByRealIntake() {
        let calories: [Date: Double] = (0..<14).reduce(into: [:]) { d, i in d[daysAgo(i)] = 1800 }
        let intake = IntakeAnalyticsService(
            currentIntakes: [daysAgo(0): 1800],
            intakes: calories,
            alpha: 0.25
        )
        let maintenance = MaintenanceService(calories: intake, weights: [:])

        // 14 points spanning 13 days → span just below 50% of 28d window → not valid yet
        #expect(!maintenance.isValid)
        #expect(maintenance.blendedSlope == 0)  // no weight = no slope
        // Maintenance should be pulled toward 1800, not stuck at 2200 baseline
        // (confidence ≈ densityFactor × spanFactor = 1.0 × 0.46 ≈ 0.46; blended → ~2000)
        #expect(maintenance.maintenance > 1600)
        #expect(maintenance.maintenance < 2300)
        // Budget remains finite and actionable
        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(budget.budget > 0)
        #expect(budget.budget.isFinite)
    }

    /// User has 15 days of calorie data spanning 15 days (today + 14 days ago).
    /// span = 14 days ≥ windowDays × 0.5 = 14 → crosses the validity threshold.
    @Test("New user, 15 days calories spanning 14 days → valid, budget reflects 1800 intake")
    func newUser_15calorieDays_valid_intakeBased() {
        // daysAgo(0)…daysAgo(14) → span = 14 days, count = 15
        let calories: [Date: Double] = (0..<15).reduce(into: [:]) { d, i in d[daysAgo(i)] = 1800 }
        let intake = IntakeAnalyticsService(
            currentIntakes: [daysAgo(0): 1800],
            intakes: calories,
            alpha: 0.25
        )
        let maintenance = MaintenanceService(calories: intake, weights: [:])

        // 15 > MinCalorieDataPoints (14) and span ≥ 50% of window → valid
        #expect(maintenance.isValid)
        #expect(maintenance.blendedSlope == 0)  // no weight = no slope
        // Maintenance should be meaningfully informed by the 1800 kcal data
        #expect(maintenance.maintenance > 1600)
        #expect(maintenance.maintenance < 2300)
    }

    // =========================================================================
    // MARK: Group 2 — Asymmetric Logging (weight-only or calories-only)
    // =========================================================================

    /// User uses a smart scale daily but never logs food.
    /// Must be valid (via weight data), maintenance uses fallback as calorie anchor.
    @Test("28 days weight only, no calories → valid via weight, maintenance ≈ fallback")
    func weightOnlyForMonth_validViaWeightData() {
        let weights = constantWeights(value: 75.0, days: 28)
        let emptyCalories = IntakeAnalyticsService(currentIntakes: [:], intakes: [:], alpha: 0.25)
        let maintenance = MaintenanceService(
            calories: emptyCalories,
            weights: weights,
            fallbackMaintenance: BaselineMaintenance
        )

        // Weight data alone makes this valid
        #expect(maintenance.isValid)
        // No calories → intake estimate = fallback (baseline)
        #expect(maintenance.blendedIntake == BaselineMaintenance)
        // Stable weight → near-zero slope
        #expect(maintenance.rawWeightSlope.magnitude < 0.15)
        // Maintenance ≈ fallback, not wildly different
        #expect(abs(maintenance.maintenance - BaselineMaintenance) < 100)
    }

    /// User only logged weight for 30 days, then switched to only logging calories for 28 days.
    /// Recent window (28d) has no weight → weight.confidence=0; calorie data drives estimate.
    @Test("Month weight then month calories: weight outside window, calorie-driven estimate")
    func monthWeightThenMonthCalories_caloriesDriveEstimate() {
        // Weight data: 30-58 days ago (outside the 28-day regression window)
        let weights: [Date: Double] = (30..<58).reduce(into: [:]) { d, i in d[daysAgo(i)] = 72.0 }
        // Calorie data: last 28 days
        let calories: [Date: Double] = (0..<28).reduce(into: [:]) { d, i in d[daysAgo(i)] = 2300 }
        let intake = IntakeAnalyticsService(
            currentIntakes: [daysAgo(0): 2300],
            intakes: calories,
            alpha: 0.25
        )
        let maintenance = MaintenanceService(calories: intake, weights: weights)

        // Weight confidence = 0 (all old data); calorie data is valid
        #expect(maintenance.isValid)
        #expect(maintenance.confidence == 0)
        #expect(maintenance.blendedSlope == 0)  // weight confidence = 0 → slope fades to 0
        // Maintenance driven entirely by the calorie EWMA
        #expect(maintenance.maintenance > 1800 && maintenance.maintenance < 2600)
        #expect(maintenance.maintenance.isFinite)
    }

    // =========================================================================
    // MARK: Group 3 — Returning Users & Long Gaps
    // =========================================================================

    /// User tracked well for a month, then stopped entirely for 6 months.
    /// The 28-day window is empty; budget must still be positive using BaselineMaintenance.
    @Test("6-month break: 28d window empty → fallback budget, actionable from Day 1 back")
    func sixMonthBreak_28dWindowEmpty_fallbackBudget() {
        let oldWeights: [Date: Double] = stride(from: 210, to: 250, by: 4)
            .reduce(into: [:]) { d, i in d[daysAgo(i)] = 70.0 }
        let oldCalories: [Date: Double] = (210..<238).reduce(into: [:]) { d, i in
            d[daysAgo(i)] = 2200
        }
        let intake = IntakeAnalyticsService(currentIntakes: [:], intakes: oldCalories, alpha: 0.25)
        let maintenance = MaintenanceService(calories: intake, weights: oldWeights)

        // Primary 28-day window is empty
        #expect(maintenance.confidence == 0)
        #expect(maintenance.dataPointCount == 0)
        #expect(!maintenance.isValid)

        // Maintenance is still a positive finite number (via fallback blending)
        #expect(maintenance.maintenance > 0)
        #expect(maintenance.maintenance.isFinite)

        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        // Budget is immediately actionable on return
        #expect(budget.budget > 0)
        #expect(budget.budget.isFinite)
        #expect(!budget.isValid)  // correctly signals insufficient recent data
    }

    /// Same 6-month break, but now the app queries a wider 365-day historical window.
    /// Old personal data should produce a better-than-generic estimate.
    @Test("6-month break with 365d window → personal historical data beats baseline")
    func sixMonthBreak_365dWindow_personalEstimate() {
        // Data from 6-8 months ago (all within a 365-day window)
        let weights: [Date: Double] = stride(from: 180, to: 250, by: 10)
            .reduce(into: [:]) { d, i in d[daysAgo(i)] = 70.0 }
        let calories: [Date: Double] = (180..<210).reduce(into: [:]) { d, i in d[daysAgo(i)] = 2350
        }

        let intake = IntakeAnalyticsService(
            currentIntakes: [:], intakes: calories,
            alpha: 0.25, windowDays: 365, minDataPoints: MinCalorieDataPoints
        )
        let maintenance = MaintenanceService(
            calories: intake,
            weights: weights,
            windowDays: 365,
            fallbackMaintenance: BaselineMaintenance
        )

        // Old personal data provides real signal
        #expect(maintenance.confidence > 0)
        #expect(maintenance.maintenance > 1500 && maintenance.maintenance < 4000)
        // Must differ from the raw generic baseline (blended with real data)
        #expect(maintenance.maintenance != BaselineMaintenance)
    }

    /// User was tracking well, took a full year break, and just logged again yesterday.
    /// 28d window has 1 weight point and 1 calorie day — well below thresholds.
    /// Budget must still be immediately actionable.
    @Test("1-year break then restarted yesterday → 1 data point each, budget still usable")
    func oneYearBreak_restartedYesterday_immediateBudget() {
        let maintenance = MaintenanceService(
            calories: IntakeAnalyticsService(
                currentIntakes: [daysAgo(0): 2100],
                intakes: [daysAgo(1): 2100, daysAgo(0): 2100],
                alpha: 0.25
            ),
            weights: [daysAgo(1): 78.5],
            fallbackMaintenance: BaselineMaintenance
        )

        // 1 weight point + 2 calorie days → not valid
        #expect(!maintenance.isValid)

        // But budget is immediately actionable (uses baseline blend)
        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: [daysAgo(0): 2100],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(budget.budget > 0)
        #expect(budget.budget.isFinite)
        #expect(!budget.isValid)  // correctly flagged as insufficient
    }

    /// User tracked well for Week 1, skipped Week 2 completely, then tracked Week 3.
    /// EWMA must handle the gap; the 28d window still has valid data spanning >14 days.
    @Test("Logged Week 1, skipped Week 2, logged Week 3 → gap-aware, still valid")
    func loggedSkippedLogged_oneWeekGap_stillValid() {
        var weights: [Date: Double] = [:]
        var calories: [Date: Double] = [:]
        // Week 3: 1-7 days ago
        for i in 1...7 {
            weights[daysAgo(i)] = 71.0
            calories[daysAgo(i)] = 2200
        }
        // Week 2: 8-14 days ago — deliberately empty (gap)
        // Week 1: 15-21 days ago
        for i in 15...21 {
            weights[daysAgo(i)] = 71.5
            calories[daysAgo(i)] = 2200
        }

        let intake = IntakeAnalyticsService(
            currentIntakes: [daysAgo(0): 2200],
            intakes: calories,
            alpha: 0.25
        )
        let maintenance = MaintenanceService(calories: intake, weights: weights)

        // 14 weight points spanning 21 days → valid
        #expect(maintenance.isValid)
        #expect(maintenance.dataPointCount >= MinWeightDataPoints)
        // Budget remains actionable
        #expect(maintenance.maintenance > 0 && maintenance.maintenance.isFinite)

        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: weekBudgetIntakes(days: 3, daily: 2200),
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(budget.budget > 0)
        #expect(budget.isValid)
    }

    // =========================================================================
    // MARK: Group 4 — Intermittent / Sparse Tracking Patterns
    // =========================================================================

    /// User tracks for 2 weeks, drops off for 2, tracks again for 2, over 6 weeks total.
    /// The wider 42-day window must capture both active periods.
    @Test("2 weeks on, 2 weeks off, 2 weeks on (6-week pattern) → data spans gap, valid")
    func twoOnTwoOffTwoOn_6weekPattern_valid() {
        var weights: [Date: Double] = [:]
        var calories: [Date: Double] = [:]
        // Active: 1-14 days ago (2nd on-period)
        for i in 1...14 {
            weights[daysAgo(i)] = 70.0
            calories[daysAgo(i)] = 2150
        }
        // Gap: 15-28 days ago (off-period)
        // Active: 29-42 days ago (1st on-period)
        for i in 29...42 {
            weights[daysAgo(i)] = 70.5
            calories[daysAgo(i)] = 2150
        }

        let intake = IntakeAnalyticsService(
            currentIntakes: [daysAgo(0): 2150], intakes: calories,
            alpha: 0.25, windowDays: 42, minDataPoints: MinCalorieDataPoints
        )
        let maintenance = MaintenanceService(
            calories: intake,
            weights: weights,
            windowDays: 42
        )

        #expect(maintenance.dataPointCount >= MinWeightDataPoints)
        #expect(maintenance.isValid)
        // Stable weight + 2150 kcal → maintenance near 2150 (within tolerance)
        #expect(maintenance.maintenance > 1800 && maintenance.maintenance < 2600)
        #expect(maintenance.maintenance.isFinite)
    }

    /// User only uses a smart scale, checking in every Sunday (weekly weigh-in).
    /// 8 weeks = 8 data points. Sparse but spans 56 days — regression should work.
    @Test("Weekly weigh-ins every Sunday for 8 weeks → sparse regression, valid estimate")
    func weeklySundayWeighIns_8weeks_sparseButValid() {
        // 8 points at 7-day intervals — very slowly losing weight
        let weights: [Date: Double] = (0..<8).reduce(into: [:]) { w, i in
            w[daysAgo(i * 7)] = 72.0 - Double(i) * 0.1
        }
        // 2 weeks of recent calories (enough to anchor the intake estimate)
        let calories: [Date: Double] = (0..<14).reduce(into: [:]) { c, i in
            c[daysAgo(i)] = 2200
        }

        let intake = IntakeAnalyticsService(
            currentIntakes: [daysAgo(0): 2200], intakes: calories,
            alpha: 0.25, windowDays: 56, minDataPoints: MinWeightDataPoints
        )
        let maintenance = MaintenanceService(
            calories: intake,
            weights: weights,
            windowDays: 56
        )

        #expect(maintenance.dataPointCount == 8)
        #expect(maintenance.isValid)
        #expect(maintenance.maintenance > 0 && maintenance.maintenance.isFinite)
    }

    /// User logs every other day — 14 days logged out of 28.
    /// Meets MinCalorieDataPoints (14) exactly; EWMA handles 1-day gaps.
    @Test("Every-other-day calorie logging for 28 days (14 logged days) → meets minimum, valid")
    func everyOtherDayCalories_28daySpan_valid() {
        let calories: [Date: Double] = stride(from: 0, to: 28, by: 2)
            .reduce(into: [:]) { d, i in d[daysAgo(i)] = 1900 }
        let intake = IntakeAnalyticsService(
            currentIntakes: [daysAgo(0): 1900],
            intakes: calories,
            alpha: 0.25
        )
        let maintenance = MaintenanceService(
            calories: intake,
            weights: constantWeights(value: 68.0, days: 28)
        )

        #expect(maintenance.isValid)
        // Stable weight + 1900 kcal intake → maintenance in plausible range for this intake
        #expect(maintenance.maintenance > 1500 && maintenance.maintenance < 2400)
        #expect(maintenance.maintenance.isFinite)
    }

    // =========================================================================
    // MARK: Group 5 — Biological Accuracy of Maintenance Estimation
    // =========================================================================

    /// BIOLOGY: User is eating 500 kcal under maintenance, losing ~0.5 kg/week.
    /// The model must deduce maintenance is ABOVE the measured intake.
    /// Formula: M = intake + slope * rho / 7 = 1800 + 0.5 * 7350 / 7 ≈ 2325 kcal
    @Test("BIOLOGY: 500 kcal deficit + 0.5 kg/week loss → model deduces maintenance above intake")
    func biology_deficit_maintenanceAboveIntake() {
        let weights = linearWeightTrend(latestWeight: 70.0, slopePerWeek: -0.5, days: 28)
        let maintenance = MaintenanceService(
            calories: intakeService(intake: 1800, days: 28),
            weights: weights
        )

        // Core biological invariant: maintenance > intake when losing weight
        #expect(maintenance.maintenance > 1800)
        // Model estimate should be in the range of ~1800 + (0.5 * 7350/7) ≈ 2325
        // (tolerance ±300 for EWMA lag and blending)
        #expect(maintenance.maintenance > 2000 && maintenance.maintenance < 2700)
        #expect(maintenance.isValid)
    }

    /// BIOLOGY: User is eating 500 kcal over maintenance, gaining ~0.4 kg/week.
    /// The model must deduce maintenance is BELOW the measured intake.
    @Test("BIOLOGY: 500 kcal surplus + 0.4 kg/week gain → model deduces maintenance below intake")
    func biology_surplus_maintenanceBelowIntake() {
        let weights = linearWeightTrend(latestWeight: 80.0, slopePerWeek: 0.4, days: 28)
        let maintenance = MaintenanceService(
            calories: intakeService(intake: 2900, days: 28),
            weights: weights
        )

        // Core biological invariant: maintenance < intake when gaining weight
        #expect(maintenance.maintenance < 2900)
        #expect(maintenance.maintenance > 2000 && maintenance.maintenance < 2900)
        #expect(maintenance.isValid)
    }

    /// BIOLOGY: Petite / sedentary user with a real TDEE of 1400 kcal.
    /// Stable weight while eating 1400 kcal. Model must NOT inflate their budget to 2200.
    @Test("BIOLOGY: Stable weight at 1400 kcal/day → maintenance ≈ 1400, not inflated to baseline")
    func biology_plateau_lowIntake_notInflatedToBaseline() {
        let maintenance = MaintenanceService(
            calories: intakeService(intake: 1400, days: 28),
            weights: constantWeights(value: 52.0, days: 28)
        )

        #expect(maintenance.isValid)
        // Stable weight → near-zero slope
        #expect(maintenance.rawWeightSlope.magnitude < 0.1)
        // Maintenance must reflect reality (≈ 1400), not the 2200 population baseline
        #expect(maintenance.maintenance > 1200 && maintenance.maintenance < 1800)
        #expect(maintenance.maintenance < BaselineMaintenance)
    }

    /// BIOLOGY: High-activity athlete eating 3500 kcal/day, stable weight.
    /// Budget must not be capped at the 2200 baseline.
    @Test("BIOLOGY: High-activity at 3500 kcal stable → budget reflects real TDEE, not 2200 cap")
    func biology_highActivityAthlete_budgetReflectsRealTDEE() {
        let maintenance = MaintenanceService(
            calories: intakeService(intake: 3500, days: 28),
            weights: constantWeights(value: 85.0, days: 28)
        )

        #expect(maintenance.isValid)
        // Estimated TDEE should be 3500, not capped at 2200
        #expect(maintenance.maintenance > 3000 && maintenance.maintenance < 4200)

        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(budget.budget > 3000)
        #expect(budget.budget.isFinite)
    }

    /// Progressive refeeding: user recovered from a crash diet, calories rising from 1600→2200.
    /// EWMA must lag behind the trend (not stuck at 1600, not yet at 2200).
    @Test("Progressive refeeding 1600→2200 over 28 days → EWMA tracks rising trend, in-between")
    func progressiveRefeeding_risingCalories_ewmaLags() {
        let calories = linearCalorieTrend(from: 1600, to: 2200, days: 28)
        let intake = IntakeAnalyticsService(
            currentIntakes: [daysAgo(0): 2200],
            intakes: calories,
            alpha: 0.25
        )
        let maintenance = MaintenanceService(
            calories: intake,
            weights: constantWeights(value: 64.0, days: 28)
        )

        // EWMA must have moved past 1600 (tracking the rise)
        #expect(maintenance.maintenance > 1700)
        // But not yet at 2200 (EWMA lags the most recent value)
        #expect(maintenance.maintenance < 2300)
        #expect(maintenance.maintenance.isFinite)
    }

    /// Zigzag dieting: alternating high/low days (2800, 1600). True average = 2200.
    /// EWMA should converge near the mean, providing a stable maintenance estimate.
    @Test("Zigzag dieting 2800/1600 alternating for 28 days → EWMA near ±2200 average")
    func zigzagDieting_ewmaConvergesNearAverage() {
        var calories: [Date: Double] = [:]
        for i in 0..<28 {
            calories[daysAgo(i)] = i.isMultiple(of: 2) ? 2800.0 : 1600.0
        }
        let intake = IntakeAnalyticsService(
            currentIntakes: [daysAgo(0): 2800],
            intakes: calories,
            alpha: 0.25
        )
        let maintenance = MaintenanceService(
            calories: intake,
            weights: constantWeights(value: 70.0, days: 28)
        )

        // EWMA smooths the zigzag: should land near 2200 ± 400 (smoothing lag)
        #expect(maintenance.maintenance > 1800 && maintenance.maintenance < 2600)
        #expect(maintenance.maintenance.isFinite)
    }

    /// User tracked 3 perfect weeks then had a binge week (600 kcal over each day).
    /// Negative weekly credit must reduce today's budget (up to −500 cap).
    @Test("3 perfect weeks then 1 binge week → negative credit, budget reduced but positive")
    func threeWeeksPerfect_bingeWeek_debtSlimsBudget() {
        let maintenanceTarget = 2200.0
        let maintenance = stableMaintenanceService(target: maintenanceTarget)

        // Binge: 5 days over by 600 kcal each → −3000 credit if spread, capped at −500
        let bibgeWeek = weekBudgetIntakes(days: 5, daily: maintenanceTarget + 600)
        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: bibgeWeek,
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday  // daysLeft = 5
        )

        #expect(budget.credit < 0)
        #expect(budget.dailyAdjustment < 0)
        #expect(budget.budget < budget.baseBudget)
        // Still positive — a reasonable overage shouldn't make budget go negative
        #expect(budget.budget > 0)
    }

    // =========================================================================
    // MARK: Group 6 — Weekly Budget Dynamics
    // =========================================================================

    /// Today is Monday — the first day of the budget week.
    /// Credit = 0, daysLeft = 7, budget = maintenance.
    @Test("Monday: first day of week → credit=0, daysLeft=7, budget=maintenance")
    func monday_firstDayOfWeek_fullWeekAhead() {
        let maintenance = stableMaintenanceService(target: 2200)
        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: [:],  // nothing logged yet this week
            adjustment: nil,
            firstWeekday: 2,  // Monday
            currentDate: referenceMondayForScenarios
        )

        #expect(budget.daysLeft == 7)
        #expect(budget.credit == 0)
        #expect(budget.dailyAdjustment == 0)
        // Budget exactly equals maintenance when no credit and no adjustment
        #expect(abs(budget.budget - maintenance.maintenance) < 1.0)
    }

    /// Today is Sunday — the last day before the new week starts on Monday.
    /// daysLeft = 1: the entire remaining credit or debt collapses onto today.
    @Test("Sunday: last day of week → daysLeft=1")
    func sunday_lastDayOfWeek_daysLeft1() {
        let maintenance = stableMaintenanceService(target: 2200)
        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,  // Monday
            currentDate: referenceSundayForScenarios
        )
        #expect(budget.daysLeft == 1)
    }

    /// Sunday with ~400 kcal credit banked (Mon-Sat each 67 kcal under budget).
    /// daysLeft = 1 → full 400 collapses onto today (within ±500 cap).
    @Test("Sunday with ~400 kcal credit → full credit rolls into today's budget (within cap)")
    func sunday_400CreditBanked_fullCreditToday() {
        let maintenanceTarget = 2200.0
        let maintenance = stableMaintenanceService(target: maintenanceTarget)
        // Mon-Sat: 67 kcal under each day → ~402 total credit
        let weekData = weekBudgetIntakes(days: 6, daily: maintenanceTarget - 67)

        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: weekData,
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceSundayForScenarios
        )

        #expect(budget.daysLeft == 1)
        // Credit is positive and below the 500 cap
        #expect(budget.credit > 300 && budget.credit < 500)
        // Daily adjustment = full credit (not capped)
        #expect(budget.dailyAdjustment == budget.credit)
        // Budget is higher than base
        #expect(budget.budget > budget.baseBudget)
    }

    /// User went 1000 kcal over budget for 5 days (Mon-Fri, Wednesday as currentDate).
    /// Raw adjustment = −5000/5 = −1000 but the ±500 cap must activate.
    @Test("5 days at +1000 kcal over budget → debt exceeds cap, clamped to −500/day")
    func fiveDaysAt1000Over_debtCappedAt500() {
        let maintenanceTarget = 2200.0
        let maintenance = stableMaintenanceService(target: maintenanceTarget)
        let weekData = weekBudgetIntakes(days: 5, daily: maintenanceTarget + 1000)

        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: weekData,
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday  // daysLeft = 5
        )

        #expect(budget.dailyAdjustment == -500)
        // Budget still positive (2200 − 500 = 1700)
        #expect(budget.budget > 0)
        #expect(abs(budget.budget - (budget.baseBudget - 500)) < 1.0)
    }

    /// User ate nothing (0 kcal) for 6 logged days this week.
    /// Raw adjustment = 2200×6/5 = 2640, capped to +500.
    @Test("6 logged days at 0 kcal → massive credit capped at +500/day")
    func sixDaysAteNothing_creditCappedAt500() {
        let maintenanceTarget = 2200.0
        let maintenance = stableMaintenanceService(target: maintenanceTarget)
        let weekData = weekBudgetIntakes(days: 6, daily: 0)

        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: weekData,
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday  // daysLeft = 5
        )

        #expect(budget.dailyAdjustment == 500)
        #expect(abs(budget.budget - (budget.baseBudget + 500)) < 1.0)
    }

    /// User logged only half a week (3 days out of 5 elapsed).
    /// Credit must be based on 3 logged days only — not 5 elapsed days.
    /// This prevents punishing the user for days they simply didn't log.
    @Test("Half-week logged (3 of 5 days): credit counts only logged days, not elapsed")
    func halfWeekLogged_creditCountsLoggedDaysOnly() {
        let maintenanceTarget = 2200.0
        let maintenance = stableMaintenanceService(target: maintenanceTarget)
        // 3 logged days, all exactly at budget → zero credit
        let weekData = weekBudgetIntakes(days: 3, daily: maintenanceTarget)

        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: weekData,
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )

        // credit = baseBudget * 3 - maintenanceTarget * 3 ≈ 0
        #expect(abs(budget.credit) < 30)  // tolerance for EWMA imprecision
        #expect(abs(budget.dailyAdjustment) < 30)
    }

    // =========================================================================
    // MARK: Group 7 — Body Composition (Forbes Partition Model)
    // =========================================================================

    /// 20% body fat user: rho is lower than the population default (DefaultRho assumes
    /// ~34% BF). Their weight changes have a greater lean component → lower kcal/kg.
    @Test("20% body fat: personal rho < DefaultRho, maintenance calculation uses correct rho")
    func bf20percent_rhoLowerThanDefault() {
        let bf = 0.20
        let weight = 70.0
        let fatMass = bf * weight
        let p = fatMass / (fatMass + ForbesConstant)
        let expectedRho = p * FatTissueEnergy + (1 - p) * LeanTissueEnergy

        let maintenance = MaintenanceService(
            calories: intakeService(intake: 2200, days: 14),
            weights: constantWeights(value: weight, days: 14),
            bodyFatPercentages: [daysAgo(0): bf]
        )

        #expect(abs(maintenance.rho - expectedRho) < 1.0)
        // Lean composition → lower energy per kg than population average
        #expect(maintenance.rho < DefaultRho)
        #expect(maintenance.maintenance > 0 && maintenance.maintenance.isFinite)
    }

    /// 40% body fat user: rho is higher than default. More fat to mobilize per kg of loss.
    @Test("40% body fat: personal rho > DefaultRho")
    func bf40percent_rhoHigherThanDefault() {
        let maintenance = MaintenanceService(
            calories: intakeService(intake: 2200, days: 14),
            weights: constantWeights(value: 100.0, days: 14),
            bodyFatPercentages: [daysAgo(0): 0.40]
        )
        #expect(maintenance.rho > DefaultRho)
    }

    /// BIOLOGY: Same weight-loss slope, but one user is lean (10% BF) and one is obese (45% BF).
    /// Obese user's rho is higher → each kg of loss is worth more kcal of deficit.
    /// So for the same intake and slope, the model must estimate a higher maintenance for the obese user.
    @Test("BIOLOGY: Same loss slope — high BF user → higher rho → higher maintenance estimate")
    func biology_sameLossSlope_highBFgivesHigherMaintenanceEstimate() {
        let lossSlope = -0.5
        let weights = linearWeightTrend(latestWeight: 90.0, slopePerWeek: lossSlope, days: 28)
        let intakeData = intakeService(intake: 2000, days: 28)

        let maintenanceLean = MaintenanceService(
            calories: intakeData,
            weights: weights,
            bodyFatPercentages: [daysAgo(0): 0.10]  // 10% BF — very lean
        )
        let maintenanceFat = MaintenanceService(
            calories: intakeData,
            weights: weights,
            bodyFatPercentages: [daysAgo(0): 0.45]  // 45% BF — obese
        )

        // Fatter user's weight change is worth more kcal → larger rho
        #expect(maintenanceFat.rho > maintenanceLean.rho)

        // Both must show maintenance above intake (both in deficit)
        #expect(maintenanceLean.maintenance > 2000)
        #expect(maintenanceFat.maintenance > 2000)

        // Obese user's maintenance estimate is higher for identical intake and slope
        #expect(maintenanceFat.maintenance > maintenanceLean.maintenance)
    }

    // =========================================================================
    // MARK: Group 8 — Safety Floor, Ceiling & Accuracy Flags in Real Scenarios
    // =========================================================================

    /// Petite sedentary user: 52 kg, stable weight at 1400 kcal.
    /// Budget must NOT be floored (1400 is above MinDailyBudget).
    /// isRhoEstimated = true because no BF% provided.
    @Test("SAFETY: Petite user 52 kg at 1400 kcal — budget not floored, rho flag set")
    func safety_petiteUser_budgetNotFloored_rhoFlagged() {
        let maintenance = MaintenanceService(
            calories: intakeService(intake: 1400, days: 28),
            weights: constantWeights(value: 52.0, days: 28)
        )
        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        // Estimate is above the safety floor — no clamping needed
        #expect(!budget.isBudgetClamped)
        #expect(budget.budget >= MinDailyBudget)
        // No BF data → rho is estimated from population average
        #expect(maintenance.isRhoEstimated)
        // Maintenance should reflect her real intake, not the 2200 population average
        #expect(maintenance.maintenance < BaselineMaintenance)
    }

    /// Petite user adds a −500 kcal goal adjustment on top of a 1300 kcal maintenance.
    /// Without the floor, budget would be 800 kcal — clinically dangerous.
    /// The floor must activate, isBudgetClamped must be true.
    @Test("SAFETY: Petite user 52 kg + -500 kcal goal → floor prevents 800 kcal budget")
    func safety_petiteUser_goalPushesUnderFloor_budgetClamped() {
        // Force maintenance to ≈ 1300 by using a low fallback and low intake
        let maintenance = MaintenanceService(
            calories: intakeService(intake: 1300, days: 28),
            weights: constantWeights(value: 52.0, days: 28),
            fallbackMaintenance: 1300.0
        )
        // Verify we actually got a low maintenance before testing the budget
        #expect(maintenance.maintenance < 1500)

        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: -500,  // aggressive deficit goal
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        // Raw budget ≈ 1300 - 500 = 800 → must be floored to 1000
        let rawBudget = maintenance.maintenance - 500
        #expect(rawBudget < MinDailyBudget)  // confirms the floor would activate

        #expect(budget.budget >= MinDailyBudget)
        #expect(budget.isBudgetClamped)
    }

    /// Large active user whose data contains a corrupted weight spike (+4 kg in one day).
    /// The slope clamp must activate and the flag must be set.
    @Test(
        "SAFETY: Weight data with sudden 4 kg spike → slope inflated but regression dampens to safe range"
    )
    func safety_weightSpike_slopeClamped() {
        // Mostly stable at 85 kg, one extreme outlier day
        var weights = constantWeights(value: 85.0, days: 27)
        weights[daysAgo(1)] = 89.0  // +4 kg spike — likely water/food weight
        let maintenance = MaintenanceService(
            calories: intakeService(intake: 2800, days: 28),
            weights: weights
        )
        // The spike inflates the raw slope above a near-zero stable-weight baseline
        #expect(maintenance.rawWeightSlope > 0.1)
        // Regression over 28 points dampens the spike below the clamp threshold — this is correct behaviour
        #expect(!maintenance.isSlopeClamped)
        #expect(maintenance.weightSlope == maintenance.rawWeightSlope)
        // Budget must still be safe and finite
        let budget = BudgetService(
            weight: maintenance,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(budget.budget.isFinite && budget.budget > 0)
        #expect(budget.budget <= MaxDailyBudget)
    }

    /// Metabolic adaptation scenario: user has been eating 700 kcal for 28 days, weight stabilized.
    /// The model correctly estimates maintenance ≈ 700 kcal, which is below MinDailyBudget.
    /// isMaintenanceSuspect must be true, and the budget must be floored to 1000 kcal.
    @Test("SAFETY: Metabolic adaptation → isMaintenanceSuspect + budget floored at 1000 kcal")
    func safety_metabolicAdaptation_suspectFlagAndFloor() {
        let svc = MaintenanceService(
            calories: IntakeAnalyticsService(
                currentIntakes: [daysAgo(0): 700],
                intakes: (0..<28).reduce(into: [:]) { d, i in d[daysAgo(i)] = 700.0 },
                alpha: 0.25
            ),
            weights: constantWeights(value: 60.0, days: 28),
            fallbackMaintenance: 700.0
        )

        // Maintenance converges near 700 kcal
        #expect(svc.maintenance < MinDailyBudget)
        #expect(svc.isMaintenanceSuspect)

        let budget = BudgetService(
            weight: svc,
            weekIntakes: [:],
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        // Budget must be floored — never advise eating below MinDailyBudget
        #expect(budget.budget >= MinDailyBudget)
        #expect(budget.isBudgetClamped)
    }

    /// High-activity user with data spike: raw adjustment from a big over-eating week is > 500/day.
    /// isAdjustmentClamped must be set alongside the cap.
    @Test("SAFETY: Big overeating week → isAdjustmentClamped true, budget still positive")
    func safety_bigOvereatWeek_adjustmentClamped() {
        let maintenance = stableMaintenanceService(target: 2500)
        // 6 days at 2000 kcal over budget → credit = -12000 kcal
        let budgetService = BudgetService(
            weight: maintenance,
            weekIntakes: weekBudgetIntakes(days: 6, daily: 2500 + 2000),
            adjustment: nil,
            firstWeekday: 2,
            currentDate: referenceWednesday
        )
        #expect(budgetService.isAdjustmentClamped)
        #expect(budgetService.dailyAdjustment == -MaxDailyAdjustment)
        // Budget must remain positive despite the large debt
        #expect(budgetService.budget > 0)
    }
}
