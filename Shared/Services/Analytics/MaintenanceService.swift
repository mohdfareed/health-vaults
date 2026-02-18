import Foundation

// TODO: Implement body-fat percentage calculations to implement
// Hall's NIH dynamic model of energy imbalance

/// Weight analytics service for maintenance calorie estimation.
/// Implements weighted linear regression on weight trends to estimate energy balance.
///
/// ## Algorithm
/// Uses a configurable window (default 28 days) with exponential decay weighting:
/// 1. Weighted linear regression on weight data → raw slope (recent data weighted higher)
/// 2. Raw maintenance = EWMA(intake, α=0.1) - (slope × ρ / 7)
/// 3. Confidence = (points/minPoints) × (span/windowDays)
/// 4. Final maintenance = raw × confidence + fallback × (1 - confidence)
///
/// ## Two-Tier Fallback
/// When `fallbackMaintenance` is set to a personal historical estimate (from a wider
/// data window), the service blends toward the user's own data instead of a generic
/// population baseline. This provides a personalized starting point for returning users.
///
/// The weighted regression responds faster to recent changes while the long-term
/// EWMA for intake prevents single-day spikes from affecting maintenance.
public struct MaintenanceService: Sendable, Codable {
    let calories: IntakeAnalyticsService

    /// Recent daily weights (kg), oldest first
    let weights: [Date: Double]
    /// Daily body-fat percentage values (0-1), if available from HealthKit.
    let bodyFatPercentages: [Date: Double]

    /// Window size for regression and confidence (days). Default: 28.
    let windowDays: Int
    /// Fallback maintenance when confidence is low (kcal/day).
    /// Use a personal historical estimate when available, otherwise BaselineMaintenance.
    let fallbackMaintenance: Double

    /// Initialize with configurable window and fallback.
    /// - Parameters:
    ///   - calories: Intake analytics service for EWMA smoothing
    ///   - weights: Daily weight data
    ///   - bodyFatPercentages: Daily body-fat fractions (0-1) for Forbes model
    ///   - windowDays: Regression window size in days (default: RegressionWindowDays)
    ///   - fallbackMaintenance: Fallback TDEE when data is sparse (default: BaselineMaintenance)
    public init(
        calories: IntakeAnalyticsService,
        weights: [Date: Double],
        bodyFatPercentages: [Date: Double] = [:],
        windowDays: Int = Int(RegressionWindowDays),
        fallbackMaintenance: Double = BaselineMaintenance
    ) {
        self.calories = calories
        self.weights = weights
        self.bodyFatPercentages = bodyFatPercentages
        self.windowDays = windowDays
        self.fallbackMaintenance = fallbackMaintenance
    }

    /// Energy per unit weight change (kcal/kg).
    /// Computed via Forbes partition model when body fat % is available,
    /// otherwise falls back to `DefaultRho` (7350).
    var rho: Double {
        guard let bf = latestBodyFat,
              let latestWeight = latestWeight
        else { return DefaultRho }
        let fatMass = bf * latestWeight
        let p = fatMass / (fatMass + ForbesConstant)
        return p * FatTissueEnergy + (1 - p) * LeanTissueEnergy
    }

    /// Most recent weight measurement (kg).
    private var latestWeight: Double? {
        dailyWeights.max(by: { $0.key < $1.key })?.value
    }

    /// Most recent body-fat percentage in the current window, with lookback fallback.
    private var latestBodyFat: Double? {
        windowBodyFat.max(by: { $0.key < $1.key })?.value
            ?? dailyBodyFat.max(by: { $0.key < $1.key })?.value
    }

    /// Body-fat percentage currently used by the Forbes model.
    var bodyFatPercentageUsed: Double? {
        latestBodyFat
    }

    /// Daily weight buckets.
    var dailyWeights: [Date: Double] {
        return weights.bucketed(by: .day, using: .autoupdatingCurrent)
            .mapValues { $0.average() ?? .nan }
            .filter { !$0.value.isNaN }
    }

    /// Daily body-fat percentage buckets.
    private var dailyBodyFat: [Date: Double] {
        return bodyFatPercentages.bucketed(by: .day, using: .autoupdatingCurrent)
            .mapValues { $0.average() ?? .nan }
            .filter { !$0.value.isNaN }
    }

    /// Weights within the regression window.
    private var windowWeights: [Date: Double] {
        let cal = Calendar.autoupdatingCurrent
        let cutoff = Date().adding(-windowDays, .day, using: cal) ?? Date()
        return dailyWeights.filter { $0.key >= cutoff }
    }

    /// Body-fat values within the regression window.
    private var windowBodyFat: [Date: Double] {
        let cal = Calendar.autoupdatingCurrent
        let cutoff = Date().adding(-windowDays, .day, using: cal) ?? Date()
        return dailyBodyFat.filter { $0.key >= cutoff }
    }

    /// The date range for weight data within the window.
    var weightDateRange: (from: Date, to: Date)? {
        let sorted = windowWeights.keys.sorted()
        guard let min = sorted.first, let max = sorted.last else { return nil }
        return (from: min, to: max)
    }

    /// Number of distinct daily weight measurements in the window.
    var dataPointCount: Int {
        windowWeights.count
    }

    /// Number of distinct daily body-fat measurements in the window.
    var bodyFatDataPointCount: Int {
        windowBodyFat.count
    }

    /// The date range for body-fat data within the window.
    var bodyFatDateRange: (from: Date, to: Date)? {
        let sorted = windowBodyFat.keys.sorted()
        guard let min = sorted.first, let max = sorted.last else { return nil }
        return (from: min, to: max)
    }

    /// Span of data in days within the window.
    private var dataSpanDays: Double {
        guard let range = weightDateRange else { return 0 }
        return range.to.timeIntervalSince(range.from) / 86_400
    }

    /// Weight data confidence factor (0-1) based on data quality within the window.
    /// Considers both density (points/minPoints) and span (span/windowDays).
    /// Formula: confidence = densityFactor × spanFactor
    public var confidence: Double {
        let densityFactor = min(1.0, Double(dataPointCount) / Double(MinWeightDataPoints))
        let spanFactor = min(1.0, dataSpanDays / Double(windowDays))
        return densityFactor * spanFactor
    }

    /// Estimated weight-change rate (kg/week), clamped to physiological bounds.
    /// NOT damped by confidence - we want the true measured trend.
    public var weightSlope: Double {
        return rawWeightSlope.clamped(to: -MaxWeightLossPerWeek...MaxWeightGainPerWeek)
    }

    /// Raw weight slope from weighted linear regression (kg/week).
    public var rawWeightSlope: Double {
        return computeWeightedSlope * 7
    }

    // MARK: - Independent Component Blending

    /// Intake estimate, blended toward fallback based on calorie data confidence.
    /// When calorie data is sparse, blends toward the fallback (personal history or baseline).
    /// When no calorie data exists at all, returns the fallback directly.
    private var blendedIntake: Double {
        guard let smoothed = calories.longTermSmoothedIntake else {
            return fallbackMaintenance
        }
        return smoothed * calories.confidence + fallbackMaintenance * (1 - calories.confidence)
    }

    /// Weight slope blended toward 0 (stable weight) based on weight data confidence.
    /// When weight data is sparse, assumes weight is stable (slope = 0).
    private var blendedSlope: Double {
        return weightSlope * confidence
    }

    /// Raw maintenance estimate before component blending (kcal/day).
    /// Uses long-term EWMA (α=0.1) to ignore single-day intake spikes.
    public var rawMaintenance: Double {
        guard let smoothed = calories.longTermSmoothedIntake else {
            return fallbackMaintenance
        }
        let energyImbalance = weightSlope * rho / 7.0
        return smoothed - energyImbalance
    }

    /// Maintenance estimate (kcal/day) with independent component blending.
    /// Each component fades to its own neutral fallback independently:
    /// - Intake → fallbackMaintenance (when calorie data is sparse)
    /// - Slope → 0 (when weight data is sparse, assume stable weight)
    /// Then: M = blendedIntake - (blendedSlope × ρ / 7)
    public var maintenance: Double {
        return blendedIntake - (blendedSlope * rho / 7.0)
    }

    /// Whether the maintenance estimate has enough data to be considered valid.
    /// Valid when either weight OR calorie data meets minimum thresholds.
    /// Weight-only or calorie-only data still produces a useful estimate
    /// via independent component blending.
    public var isValid: Bool {
        let hasWeightData = dataPointCount >= MinWeightDataPoints
            && dataSpanDays >= Double(windowDays) * 0.5
        let hasCalorieData = calories.isValid
        return hasWeightData || hasCalorieData
    }

    /// Computes the slope (kg/day) using weighted least-squares linear regression.
    /// Recent data points are weighted exponentially higher (decay = RegressionDecay per day).
    /// This makes the regression responsive to recent trends while still using historical context.
    private var computeWeightedSlope: Double {
        let sorted = windowWeights.sorted { $0.key < $1.key }
        guard sorted.count > 1 else { return 0 }

        let today = Date()

        // Calculate weights: w_i = decay^(days_ago)
        // More recent = higher weight
        let dataWithWeights: [(t: Double, w: Double, weight: Double)] = sorted.map { entry in
            let daysAgo = today.timeIntervalSince(entry.key) / 86_400
            let regressionWeight = pow(RegressionDecay, daysAgo)
            let t = entry.key.timeIntervalSince(sorted.first!.key) / 86_400
            return (t: t, w: entry.value, weight: regressionWeight)
        }

        // Weighted means
        let totalWeight = dataWithWeights.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 0 }

        let meanX = dataWithWeights.reduce(0) { $0 + $1.t * $1.weight } / totalWeight
        let meanY = dataWithWeights.reduce(0) { $0 + $1.w * $1.weight } / totalWeight

        // Weighted covariance and variance
        let numerator = dataWithWeights.reduce(0) { acc, point in
            acc + point.weight * (point.t - meanX) * (point.w - meanY)
        }

        let denominator = dataWithWeights.reduce(0) { acc, point in
            let dx = point.t - meanX
            return acc + point.weight * dx * dx
        }

        return denominator != 0 ? numerator / denominator : 0
    }
}
