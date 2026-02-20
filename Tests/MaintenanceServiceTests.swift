import Testing
import Foundation
@testable import HealthVaultsShared

// MARK: - MaintenanceService Tests
// ============================================================================

@Suite("MaintenanceService")
struct MaintenanceServiceTests {

    // MARK: - Baseline / No Data

    @Test("No data returns fallback maintenance")
    func noData_returnsBaseline() {
        let svc = emptyMaintenanceService
        #expect(svc.maintenance == BaselineMaintenance)
        #expect(svc.confidence == 0)
        #expect(!svc.isValid)
    }

    @Test("Only calorie data (no weight) returns intake as maintenance")
    func onlyCalories_intakeAsEstimate() {
        let svc = MaintenanceService(
            calories: intakeService(intake: 2800, days: 28),
            weights: [:]
        )
        // No weight → slope = 0, blended slope = 0
        // Maintenance ≈ blendedIntake (calories have good confidence)
        // Calorie confidence will be reasonable, blending toward 2800
        let m = svc.maintenance
        // Should be between fallback (2200) and intake (2800)
        #expect(m > 2200 && m <= 2800)
        // blendedSlope must be 0 when there is no weight data
        #expect(svc.blendedSlope == 0)
    }

    @Test("Only weight data (no calories) returns fallback blended with 0-intake")
    func onlyWeights_blendsTowardFallback() {
        let emptyCalories = IntakeAnalyticsService(currentIntakes: [:], intakes: [:], alpha: 0.25)
        let svc = MaintenanceService(
            calories: emptyCalories,
            weights: constantWeights(days: 28),
            fallbackMaintenance: 2500
        )
        // No calorie data → blendedIntake = fallbackMaintenance
        #expect(svc.blendedIntake == 2500)
    }

    // MARK: - Confidence

    @Test("Dense 28-day data gives high confidence")
    func denseDailyData_highConfidence() {
        let svc = MaintenanceService(
            calories: intakeService(intake: 2200, days: 28),
            weights: constantWeights(days: 28)
        )
        // dataPointCount=28 > MinWeightDataPoints=7, span=27 of 28 days
        #expect(svc.confidence > 0.9)
        #expect(svc.isValid)
    }

    @Test("Exactly minimum weight data points gives partial confidence")
    func minimumWeightPoints_partialConfidence() {
        let svc = MaintenanceService(
            calories: intakeService(intake: 2200, days: 28),
            weights: sparseWeights(totalDaysBack: 28, stride: 4) // 7 points
        )
        let count = svc.dataPointCount
        #expect(count >= MinWeightDataPoints)
        #expect(svc.confidence > 0 && svc.confidence <= 1.0)
    }

    @Test("All data older than 28-day regression window gives zero confidence")
    func oldData_zeroConfidence() {
        // All weight data 30-60 days ago — outside the default 28-day window
        let oldWeights = (30...59).reduce(into: [Date: Double]()) { d, n in
            d[daysAgo(n)] = 70.0
        }
        let svc = MaintenanceService(
            calories: intakeService(intake: 2200, days: 28),
            weights: oldWeights
        )
        #expect(svc.confidence == 0)
        #expect(svc.dataPointCount == 0)
    }

    @Test("Data from 2 years ago outside window gives zero weight confidence")
    func twoYearOldData_zeroPrimaryConfidence() {
        let ancientWeights = (720...747).reduce(into: [Date: Double]()) { d, n in
            d[daysAgo(n)] = 75.0
        }
        let svc = MaintenanceService(
            calories: intakeService(intake: 2200, days: 28),
            weights: ancientWeights
        )
        // Primary 28-day window has no weight data
        #expect(svc.confidence == 0)
        #expect(svc.dataPointCount == 0)
        // But maintenance still blends toward fallback rather than being 0
        #expect(svc.maintenance > 0)
    }

    // MARK: - Weight Slope (Regression)

    @Test("Stable weight gives zero slope")
    func stableWeight_zeroSlope() {
        let svc = MaintenanceService(
            calories: intakeService(intake: 2200, days: 28),
            weights: constantWeights(value: 70.0, days: 28)
        )
        #expect(svc.rawWeightSlope.magnitude < 0.05)  // near-zero tolerance
    }

    @Test("Known -0.5 kg/week loss produces correct raw slope")
    func knownLoss_correctSlope() {
        let weights = linearWeightTrend(latestWeight: 70.0, slopePerWeek: -0.5, days: 28)
        let svc = MaintenanceService(
            calories: intakeService(intake: 2200, days: 28),
            weights: weights
        )
        // Weighted regression with decay; result should be close to -0.5 kg/wk
        #expect(svc.rawWeightSlope < -0.3)
        #expect(svc.rawWeightSlope > -0.7)
    }

    @Test("Known +0.4 kg/week gain produces positive slope")
    func knownGain_positiveSlope() {
        let weights = linearWeightTrend(latestWeight: 70.0, slopePerWeek: 0.4, days: 28)
        let svc = MaintenanceService(
            calories: intakeService(intake: 2200, days: 28),
            weights: weights
        )
        #expect(svc.rawWeightSlope > 0.2)
        #expect(svc.rawWeightSlope < 0.6)
    }

    @Test("Extreme loss beyond -1.0 kg/week is clamped")
    func extremeLoss_clamped() {
        let weights = linearWeightTrend(latestWeight: 60.0, slopePerWeek: -3.0, days: 28)
        let svc = MaintenanceService(
            calories: intakeService(intake: 1500, days: 28),
            weights: weights
        )
        #expect(svc.rawWeightSlope < -1.0)
        #expect(svc.weightSlope == -MaxWeightLossPerWeek)
        // Clamped and raw must differ
        #expect(svc.rawWeightSlope != svc.weightSlope)
    }

    @Test("Extreme gain beyond +0.75 kg/week is clamped")
    func extremeGain_clamped() {
        let weights = linearWeightTrend(latestWeight: 80.0, slopePerWeek: 2.0, days: 28)
        let svc = MaintenanceService(
            calories: intakeService(intake: 3500, days: 28),
            weights: weights
        )
        #expect(svc.rawWeightSlope > MaxWeightGainPerWeek)
        #expect(svc.weightSlope == MaxWeightGainPerWeek)
    }

    @Test("Moderate loss within bounds is not clamped")
    func moderateLoss_notClamped() {
        let weights = linearWeightTrend(latestWeight: 70.0, slopePerWeek: -0.5, days: 28)
        let svc = MaintenanceService(
            calories: intakeService(intake: 2000, days: 28),
            weights: weights
        )
        // Clamped == raw when within physiological bounds
        #expect(abs(svc.weightSlope - svc.rawWeightSlope) < 0.01)
    }

    // MARK: - Forbes Partition Model (ρ)

    @Test("No body fat data uses default rho")
    func noBF_defaultRho() {
        let svc = MaintenanceService(
            calories: intakeService(intake: 2200, days: 28),
            weights: constantWeights(value: 70.0, days: 28)
        )
        #expect(svc.rho == DefaultRho)
    }

    @Test("Known body fat percentage produces correct Forbes rho")
    func knownBF_correctRho() {
        // 70 kg at 20% body fat: fatMass = 14 kg
        // p = 14 / (14 + 10.4) = 0.5738
        // rho = 0.5738 * 9440 + (1 - 0.5738) * 1816
        let fatMass = 0.20 * 70.0
        let p = fatMass / (fatMass + ForbesConstant)
        let expectedRho = p * FatTissueEnergy + (1 - p) * LeanTissueEnergy

        let svc = MaintenanceService(
            calories: intakeService(intake: 2200, days: 14),
            weights: constantWeights(value: 70.0, days: 14),
            bodyFatPercentages: [daysAgo(0): 0.20]
        )
        let tolerance = 1.0
        #expect(abs(svc.rho - expectedRho) < tolerance)
        #expect(svc.rho < DefaultRho)  // 20% BF → lower rho than population avg (34% BF)
    }

    @Test("Very high body fat percentage produces higher rho")
    func highBF_higherRho() {
        let bfLow = MaintenanceService(
            calories: intakeService(intake: 2200, days: 14),
            weights: constantWeights(value: 70.0, days: 14),
            bodyFatPercentages: [daysAgo(0): 0.10]  // 10% BF (lean)
        )
        let bfHigh = MaintenanceService(
            calories: intakeService(intake: 2200, days: 14),
            weights: constantWeights(value: 70.0, days: 14),
            bodyFatPercentages: [daysAgo(0): 0.40]  // 40% BF (obese)
        )
        #expect(bfHigh.rho > bfLow.rho)
    }

    // MARK: - Maintenance Calculation & Blending

    @Test("Stable weight + known intake → maintenance ≈ intake")
    func stableWeight_maintenanceEqualsIntake() {
        let targetIntake = 2500.0
        let svc = MaintenanceService(
            calories: intakeService(intake: targetIntake, days: 28),
            weights: constantWeights(value: 70.0, days: 28)
        )
        // Stable weight → slope = 0, energy imbalance = 0
        // maintenance ≈ EWMA(intake) ≈ intake (with high calorie confidence)
        #expect(abs(svc.rawMaintenance - targetIntake) < 50)
    }

    @Test("Deficit eating + weight loss → maintenance estimate above intake")
    func deficitWithLoss_maintenanceAboveIntake() {
        // Eating 1800/day, losing 0.5 kg/week
        // Expected: maintenance ≈ 1800 + 0.5 * DefaultRho / 7 ≈ 2325
        let weights = linearWeightTrend(latestWeight: 70.0, slopePerWeek: -0.5, days: 28)
        let svc = MaintenanceService(
            calories: intakeService(intake: 1800, days: 28),
            weights: weights
        )
        #expect(svc.maintenance > 1800)
    }

    @Test("Surplus eating + weight gain → maintenance estimate below intake")
    func surplusWithGain_maintenanceBelowIntake() {
        // Eating 3000/day, gaining 0.4 kg/week → maintenance ≈ 3000 - 0.4 * DefaultRho / 7 ≈ 2580
        let weights = linearWeightTrend(latestWeight: 80.0, slopePerWeek: 0.4, days: 28)
        let svc = MaintenanceService(
            calories: intakeService(intake: 3000, days: 28),
            weights: weights
        )
        #expect(svc.maintenance < 3000)
    }

    @Test("Zero confidence → maintenance equals fallback")
    func zeroConfidence_equalsCustomFallback() {
        let customFallback = 3100.0
        let svc = MaintenanceService(
            calories: IntakeAnalyticsService(currentIntakes: [:], intakes: [:], alpha: 0.25),
            weights: [:],
            fallbackMaintenance: customFallback
        )
        #expect(svc.maintenance == customFallback)
        #expect(svc.blendedIntake == customFallback)
        #expect(svc.blendedSlope == 0)
    }

    @Test("Custom fallback is respected when confidence is low")
    func customFallback_blendedInWhenLowConfidence() {
        let customFallback = 3500.0
        // Only 1 weight point → very low confidence
        let svc = MaintenanceService(
            calories: intakeService(intake: 2200, days: 2),
            weights: [daysAgo(1): 70.0],
            fallbackMaintenance: customFallback
        )
        // With near-zero confidence: maintenance should be close to the fallback
        #expect(svc.maintenance > 2200)
        #expect(svc.maintenance <= customFallback)
    }

    @Test("blendedSlope is zero when weight confidence is zero")
    func blendedSlope_zeroWhenNoData() {
        let svc = emptyMaintenanceService
        #expect(svc.blendedSlope == 0)
    }

    @Test("blendedSlope scales with weight confidence")
    func blendedSlope_scalesWithConfidence() {
        let weights = linearWeightTrend(latestWeight: 70.0, slopePerWeek: -0.5, days: 28)
        let svc = MaintenanceService(
            calories: intakeService(intake: 2200, days: 28),
            weights: weights
        )
        let confidence = svc.confidence
        let expectedBlended = svc.weightSlope * confidence
        #expect(abs(svc.blendedSlope - expectedBlended) < 0.001)
    }

    // MARK: - isValid

    @Test("7 weight days spanning >14 days makes service valid")
    func sevenWeightPoints_spanning20days_isValid() {
        // 7 points spread across 24 days
        let weights: [Date: Double] = (0..<7).reduce(into: [:]) { d, i in
            d[daysAgo(i * 4)] = 70.0  // every 4 days = span of 24 days
        }
        let svc = MaintenanceService(
            calories: intakeService(intake: 2200, days: 28),
            weights: weights
        )
        let hasWeightData = svc.dataPointCount >= MinWeightDataPoints
        let spanOk = svc.weightDateRange.map {
            $0.to.timeIntervalSince($0.from) / 86_400 >= Double(svc.windowDays) * 0.5
        } ?? false
        #expect(hasWeightData)
        #expect(spanOk)
        #expect(svc.isValid)
    }

    @Test("14-day valid calorie window without weight data is valid")
    func validCalorieDataOnly_isValid() {
        let svc = MaintenanceService(
            calories: intakeService(intake: 2200, days: 28),
            weights: [:]
        )
        // isValid = hasWeightData || hasCalorieData
        #expect(svc.isValid)
    }

    // MARK: - Specific Scenario: returning user (data from months ago)

    @Test("Sparse data over 6 months still gives non-baseline estimate")
    func sparseMonthlyData_6months_estimatesAboveZero() {
        // Simulate a user who weighs in ~ once a month, 6 months ago to 3 months ago
        let weights: [Date: Double] = [
            daysAgo(180): 72.0,
            daysAgo(150): 71.5,
            daysAgo(120): 71.0,
            daysAgo(90): 70.5
        ]
        // Calories from 6 months ago
        let calories = (90...180).reduce(into: [Date: Double]()) { d, n in
            d[daysAgo(n)] = 2300
        }
        let svc = MaintenanceService(
            calories: IntakeAnalyticsService(
                currentIntakes: [:], intakes: calories, alpha: 0.25,
                windowDays: 180, minDataPoints: MinCalorieDataPoints
            ),
            weights: weights,
            windowDays: 180,
            fallbackMaintenance: BaselineMaintenance
        )
        // With 4 points over 90-day span, confidence should be positive
        #expect(svc.confidence > 0)
        // Maintenance should be a reasonable positive number
        #expect(svc.maintenance > 1500 && svc.maintenance < 4000)
    }
}
