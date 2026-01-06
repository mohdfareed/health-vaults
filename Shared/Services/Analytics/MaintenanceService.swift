import Foundation
import SwiftData
import SwiftUI
import WidgetKit

// TODO: Implement body-fat percentage calculations to implement
// Hall's NIH dynamic model of energy imbalance

/// Weight analytics service for maintenance calorie estimation.
/// Implements weighted linear regression on weight trends to estimate energy balance.
///
/// ## Algorithm
/// Uses a unified 28-day window with exponential decay weighting:
/// 1. Weighted linear regression on weight data → raw slope (recent data weighted higher)
/// 2. Raw maintenance = EWMA(intake, α=0.1) - (slope × ρ / 7)
/// 3. Confidence = (points/minPoints) × (span/windowDays)
/// 4. Final maintenance = raw × confidence + baseline × (1 - confidence)
///
/// The weighted regression responds faster to recent changes while the long-term
/// EWMA for intake prevents single-day spikes from affecting maintenance.
public struct MaintenanceService: Sendable {
    let calories: IntakeAnalyticsService

    /// Recent daily weights (kg), oldest first
    let weights: [Date: Double]
    /// Energy per unit weight change (kcal per kg, default is 7700)
    let rho: Double

    /// Daily weight buckets.
    var dailyWeights: [Date: Double] {
        return weights.bucketed(by: .day, using: .autoupdatingCurrent)
            .mapValues { $0.average() ?? .nan }
            .filter { !$0.value.isNaN }
    }

    /// Weights within the regression window (last 28 days).
    private var windowWeights: [Date: Double] {
        let cal = Calendar.autoupdatingCurrent
        let cutoff = Date().adding(-Int(RegressionWindowDays), .day, using: cal) ?? Date()
        return dailyWeights.filter { $0.key >= cutoff }
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

    /// Span of data in days within the window.
    private var dataSpanDays: Double {
        guard let range = weightDateRange else { return 0 }
        return range.to.timeIntervalSince(range.from) / 86_400
    }

    /// Confidence factor (0-1) based on data quality within the window.
    /// Considers both density (points/minPoints) and span (span/windowDays).
    /// Formula: confidence = densityFactor × spanFactor
    public var confidence: Double {
        let densityFactor = min(1.0, Double(dataPointCount) / Double(MinWeightDataPoints))
        let spanFactor = min(1.0, dataSpanDays / Double(RegressionWindowDays))
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

    /// Raw maintenance estimate before confidence blending (kcal/day).
    /// Uses long-term EWMA (α=0.1) to ignore single-day intake spikes.
    public var rawMaintenance: Double {
        guard let smoothed = calories.longTermSmoothedIntake else {
            return BaselineMaintenance
        }
        // M = intake - (slope × ρ / 7)
        // Use clamped slope to prevent physiologically impossible values
        let energyImbalance = weightSlope * rho / 7.0
        return smoothed - energyImbalance
    }

    /// Maintenance estimate (kcal/day), confidence-blended toward baseline.
    /// Only the final output is blended, not intermediate values.
    /// Formula: M = raw × confidence + baseline × (1 - confidence)
    public var maintenance: Double {
        return rawMaintenance * confidence + BaselineMaintenance * (1 - confidence)
    }

    /// Whether the maintenance estimate has enough data to be considered valid.
    /// Requires sufficient data from BOTH weight and calorie sources.
    public var isValid: Bool {
        return dataPointCount >= MinWeightDataPoints
            && dataSpanDays >= Double(RegressionWindowDays) * 0.5
            && calories.isValid
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
