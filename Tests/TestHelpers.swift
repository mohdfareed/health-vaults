import Foundation
@testable import HealthVaultsShared

// MARK: - Date Helpers

/// Returns a date exactly `days` before now, floored to the start of the day.
func daysAgo(_ days: Int) -> Date {
    let cal = Calendar.autoupdatingCurrent
    let base = cal.startOfDay(for: Date())
    return cal.date(byAdding: .day, value: -days, to: base)!
}

/// Fixed reference Wednesday (2024-01-03). Used wherever a stable pivot is needed.
let referenceWednesday: Date = {
    var comps = DateComponents()
    comps.year = 2024; comps.month = 1; comps.day = 3
    comps.hour = 12; comps.minute = 0; comps.second = 0
    return Calendar(identifier: .gregorian).date(from: comps)!
}()

// MARK: - Data Factories

/// Daily constant-value weights, newest entry at daysAgo(0).
func constantWeights(value: Double = 70.0, days: Int) -> [Date: Double] {
    (0..<days).reduce(into: [:]) { $0[daysAgo($1)] = value }
}

/// Daily constant-value calories.
func constantCalories(value: Double = 2200.0, days: Int) -> [Date: Double] {
    (0..<days).reduce(into: [:]) { $0[daysAgo($1)] = value }
}

/// Sparse weight data: every `stride`-th day over a range.
func sparseWeights(value: Double = 70.0, totalDaysBack: Int, stride: Int) -> [Date: Double] {
    stride_over(stride, in: totalDaysBack).reduce(into: [:]) { $0[daysAgo($1)] = value }
}

private func stride_over(_ stride: Int, in range: Int) -> [Int] {
    var result: [Int] = []
    var i = 0
    while i < range {
        result.append(i)
        i += stride
    }
    return result
}

/// Linear weight trend: weight changes at `slopePerWeek` kg/week.
/// daysAgo(0) is the most recent point. Older entries are further from the target.
func linearWeightTrend(
    latestWeight: Double, slopePerWeek: Double, days: Int
) -> [Date: Double] {
    (0..<days).reduce(into: [:]) { dict, daysBack in
        // daysBack days ago the weight was further along the slope
        let weightThen = latestWeight - (slopePerWeek / 7.0) * Double(daysBack)
        dict[daysAgo(daysBack)] = weightThen
    }
}

/// Minimal IntakeAnalyticsService with constant daily intake.
func intakeService(
    intake: Double,
    days: Int,
    windowDays: Int = Int(RegressionWindowDays)
) -> IntakeAnalyticsService {
    IntakeAnalyticsService(
        currentIntakes: [daysAgo(0): intake],
        intakes: constantCalories(value: intake, days: days),
        alpha: 0.25,
        windowDays: windowDays,
        minDataPoints: MinCalorieDataPoints
    )
}

/// Minimal MaintenanceService with zero calories and no weights (falls back to baseline).
var emptyMaintenanceService: MaintenanceService {
    MaintenanceService(
        calories: IntakeAnalyticsService(currentIntakes: [:], intakes: [:], alpha: 0.25),
        weights: [:]
    )
}
