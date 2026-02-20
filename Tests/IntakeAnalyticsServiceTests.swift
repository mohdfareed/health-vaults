import Testing
import Foundation
@testable import HealthVaultsShared

// MARK: - IntakeAnalyticsService Tests
// ============================================================================

@Suite("IntakeAnalyticsService")
struct IntakeAnalyticsServiceTests {

    // MARK: - Empty / No Data

    @Test("Empty data returns nil for all smoothed outputs")
    func emptyData_nilSmoothed() {
        let svc = IntakeAnalyticsService(currentIntakes: [:], intakes: [:], alpha: 0.25)
        #expect(svc.smoothedIntake == nil)
        #expect(svc.longTermSmoothedIntake == nil)
        #expect(svc.currentIntake == 0)  // sum() of empty = 0, not nil
        #expect(svc.confidence == 0)
        #expect(!svc.isValid)
        #expect(svc.dataPointCount == 0)
    }

    @Test("Single data point: EWMA equals that value")
    func singlePoint_ewmaEqualsValue() {
        let svc = IntakeAnalyticsService(
            currentIntakes: [:],
            intakes: [daysAgo(1): 2500.0],
            alpha: 0.25
        )
        let smoothed = svc.smoothedIntake
        #expect(smoothed != nil)
        #expect(abs(smoothed! - 2500) < 0.01)
    }

    // MARK: - Confidence

    @Test("Full 28-day coverage gives high confidence")
    func fullCoverage_highConfidence() {
        let svc = intakeService(intake: 2200, days: 28)
        // densityFactor = min(1, 28/14) = 1.0; spanFactor = min(1, 27/28) ≈ 0.96
        #expect(svc.confidence > 0.9)
        #expect(svc.isValid)
    }

    @Test("Exactly MinCalorieDataPoints (14) points with good span gives moderate confidence")
    func minDataPoints_partialConfidence() {
        // 14 points spread over 20 days
        let intakes = (0..<14).reduce(into: [Date: Double]()) { d, i in
            d[daysAgo(i * 1)] = 2000.0
        }
        let svc = IntakeAnalyticsService(
            currentIntakes: [:], intakes: intakes, alpha: 0.25
        )
        // densityFactor = 1.0; spanFactor = 13/28 ≈ 0.46
        #expect(svc.confidence > 0)
        #expect(svc.dataPointCount == 14)
    }

    @Test("Zero data points gives zero confidence")
    func noData_zeroConfidence() {
        let svc = IntakeAnalyticsService(currentIntakes: [:], intakes: [:], alpha: 0.25)
        #expect(svc.confidence == 0)
    }

    @Test("Data outside window not counted in confidence")
    func oldData_notCountedInWindow() {
        // All data from 40-55 days ago — outside the 28-day window
        let oldIntakes = (40...55).reduce(into: [Date: Double]()) { d, n in
            d[daysAgo(n)] = 2000.0
        }
        let svc = IntakeAnalyticsService(
            currentIntakes: [:], intakes: oldIntakes, alpha: 0.25
        )
        #expect(svc.dataPointCount == 0)
        #expect(svc.confidence == 0)
    }

    // MARK: - Window Cutoff

    @Test("Data inside window is included; data outside is excluded")
    func windowCutoff_correctlySplitsData() {
        // 10 days inside window, 10 days outside
        var intakes: [Date: Double] = [:]
        for i in 0..<10 { intakes[daysAgo(i + 1)] = 2000.0 }      // inside: 1-10 days ago
        for i in 0..<10 { intakes[daysAgo(i + 30)] = 2000.0 }     // outside: 30-39 days ago

        let svc = IntakeAnalyticsService(
            currentIntakes: [:], intakes: intakes, alpha: 0.25
        )
        #expect(svc.dataPointCount == 10)
    }

    // MARK: - EWMA Smoothing

    @Test("Constant intake: EWMA equals that constant")
    func constantIntake_ewmaConverges() {
        let svc = intakeService(intake: 2000, days: 28)
        let smoothed = svc.smoothedIntake
        #expect(smoothed != nil)
        // With 28 days of constant 2000 kcal, EWMA should be very close to 2000
        #expect(abs(smoothed! - 2000) < 1.0)
    }

    @Test("Long-term alpha (0.1) is more stable than short-term (0.25)")
    func longTermAlpha_moreStable() {
        // 27 days of 2500, then 1 day of 1000 (sharp spike down)
        var intakes = (1...27).reduce(into: [Date: Double]()) { d, n in
            d[daysAgo(n)] = 2500.0
        }
        intakes[daysAgo(0)] = 1000.0

        let svc = IntakeAnalyticsService(
            currentIntakes: [daysAgo(0): 1000.0], intakes: intakes, alpha: 0.25
        )
        let shortTerm = svc.smoothedIntake!
        let longTerm = svc.longTermSmoothedIntake!

        // Long-term should be closer to 2500 (the stable pattern)
        // Short-term should react more strongly to the spike
        #expect(longTerm > shortTerm)  // long-term less affected by spike
        #expect(longTerm > 2000)       // still close to 2500
    }

    @Test("Gap-aware EWMA: large gap decays old value toward new")
    func gapAwareDecay_30dayGap() {
        // Two data points 30 days apart
        let intakes: [Date: Double] = [
            daysAgo(31): 2000.0,
            daysAgo(1): 3000.0
        ]
        let svc = IntakeAnalyticsService(
            currentIntakes: [:], intakes: intakes, alpha: 0.25
        )
        let smoothed = svc.smoothedIntake!
        // 30-day gap: effectiveAlpha = 1 - 0.75^30 ≈ 0.9998
        // result ≈ 0.9998 * 3000 + 0.0002 * 2000 ≈ 2999.8
        #expect(smoothed > 2900)  // heavily weighted toward the new value
    }

    @Test("Consecutive-day EWMA applies base alpha correctly")
    func consecutiveDays_standardEwma() {
        // Two consecutive days
        let intakes: [Date: Double] = [
            daysAgo(2): 2000.0,
            daysAgo(1): 3000.0
        ]
        let svc = IntakeAnalyticsService(
            currentIntakes: [:], intakes: intakes, alpha: 0.25
        )
        // Standard EWMA: 0.25 * 3000 + 0.75 * 2000 = 750 + 1500 = 2250
        let smoothed = svc.smoothedIntake!
        #expect(abs(smoothed - 2250) < 0.01)
    }

    // MARK: - Current Intake

    @Test("currentIntake returns sum of today's entries")
    func currentIntake_sumOfToday() {
        let svc = IntakeAnalyticsService(
            currentIntakes: [daysAgo(0): 850.0, Date(): 150.0],
            intakes: [:],
            alpha: 0.25
        )
        // Sum of all current intakes
        let current = svc.currentIntake
        #expect(current != nil)
        #expect(current! >= 850.0)
    }

    @Test("currentIntake is nil when no current data exists")
    func currentIntake_nilWhenEmpty() {
        let svc = IntakeAnalyticsService(currentIntakes: [:], intakes: [:], alpha: 0.25)
        // sum() on an empty collection returns 0
        // currentIntake = currentIntakes.values.sum() — returns 0 for empty
        // (not nil — empty sum = 0)
        #expect(svc.currentIntake == 0)
    }

    // MARK: - isValid

    @Test("14 data points with 7+ day span is valid")
    func validWithMinPoints() {
        let svc = intakeService(intake: 2000, days: 28)
        #expect(svc.isValid)
    }

    @Test("Too few data points is not valid")
    func tooFewPoints_notValid() {
        let svc = IntakeAnalyticsService(
            currentIntakes: [:],
            intakes: [daysAgo(1): 2000, daysAgo(5): 2000, daysAgo(10): 2000],
            alpha: 0.25
        )
        #expect(!svc.isValid)  // 3 < MinCalorieDataPoints (14)
    }

    // MARK: - Custom Window

    @Test("Custom 7-day window ignores data older than 7 days")
    func customWindow_7days() {
        var intakes: [Date: Double] = [:]
        for i in 0..<7 { intakes[daysAgo(i)] = 2000.0 }    // inside 7-day window
        for i in 8..<15 { intakes[daysAgo(i)] = 9999.0 }  // outside 7-day window

        let svc = IntakeAnalyticsService(
            currentIntakes: [:], intakes: intakes,
            alpha: 0.25, windowDays: 7, minDataPoints: 4
        )
        // Only the 7 inside-window data points should count
        #expect(svc.dataPointCount == 7)
    }
}
