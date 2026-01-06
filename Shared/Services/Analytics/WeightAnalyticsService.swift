import Foundation
import SwiftData
import SwiftUI
import WidgetKit

// TODO: Implement body-fat percentage calculations to implement
// Hall’s NIH dynamic model of energy imbalance

/// Weight analytics service for maintenance calorie estimation.
/// Implements linear regression on weight trends to estimate energy balance.
public struct WeightAnalyticsService: Sendable {
    let calories: DataAnalyticsService

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

    /// The date range for weight data.
    var weightDateRange: (from: Date, to: Date)? {
        let max = dailyWeights.keys.sorted().max()
        let min = dailyWeights.keys.sorted().min()
        guard let max: Date = max, let min: Date = min else { return nil }
        return (from: min, to: max)
    }

    /// Number of distinct daily weight measurements.
    var dataPointCount: Int {
        dailyWeights.count
    }

    /// Data span in days between first and last measurement.
    var dataSpanDays: Int {
        guard let range = weightDateRange else { return 0 }
        return range.from.distance(
            to: range.to, in: .day, using: .autoupdatingCurrent
        ) ?? 0
    }

    /// Confidence factor (0-1) based on data quality.
    /// Combines data point density and time span requirements.
    /// Low confidence dampens the slope estimate toward zero.
    public var confidence: Double {
        let pointConfidence = min(1.0, Double(dataPointCount) / Double(MinWeightDataPoints))
        let spanConfidence = min(1.0, Double(dataSpanDays) / Double(MinWeightSpanDays))
        return pointConfidence * spanConfidence
    }

    /// Daily energy imbalance ΔE = m * rho (kcal/week)
    var energyImbalance: Double {
        return weightSlope * rho
    }

    /// Estimated weight-change rate m (kg/week), confidence-blended and clamped.
    /// With insufficient data, blends toward 0 kg/week baseline.
    /// Clamped to physiological bounds to prevent absurd values.
    public var weightSlope: Double {
        let rawSlope = computeSlope * 7  // kg/week
        // Blend toward 0 baseline: slope = raw * confidence + 0 * (1 - confidence)
        let blendedSlope = rawSlope * confidence
        // Clamp to physiological bounds
        return blendedSlope.clamped(to: -MaxWeightLossPerWeek...MaxWeightGainPerWeek)
    }

    /// Raw (undamped, unclamped) weight slope for diagnostics (kg/week).
    public var rawWeightSlope: Double {
        return computeSlope * 7
    }

    /// Maintenance estimate M (kcal/day), confidence-blended toward baseline.
    /// With insufficient data, blends toward BaselineMaintenance (2000 kcal/day).
    /// Always returns a value (never nil) for usable budgets.
    public var maintenance: Double {
        let rawMaintenance: Double
        if let smoothed = calories.smoothedIntake {
            rawMaintenance = smoothed - (energyImbalance / 7.0)
        } else {
            rawMaintenance = BaselineMaintenance
        }
        // Blend toward baseline: M = raw * confidence + baseline * (1 - confidence)
        return rawMaintenance * confidence + BaselineMaintenance * (1 - confidence)
    }

    /// Whether the maintenance estimate has enough data to be valid.
    /// Requires valid data from BOTH weight and calorie sources.
    public var isValid: Bool {
        guard weightDateRange != nil else { return false }
        let weightValid = dataPointCount >= MinWeightDataPoints && dataSpanDays >= MinWeightSpanDays
        return weightValid && calories.isValid
    }

    /// Computes the slope (Δy/Δx) of time-series data using least-squares linear regression.
    /// Uses RAW weights (not EWMA) - linear regression already handles noise.
    /// - Returns: the slope in units per day (e.g., kg/day)
    private var computeSlope: Double {
        // Use raw daily weights for accurate slope
        let sorted = dailyWeights.sorted { $0.key < $1.key }
        guard sorted.count > 1 else { return 0 }

        // Convert to (t, w) arrays where t is days since first measurement
        let firstDate = sorted.first!.key
        let t = sorted.map { $0.key.timeIntervalSince(firstDate) / 86_400 }
        let w = sorted.map { $0.value }
        let n = t.count

        let meanX = t.reduce(0, +) / Double(n)
        let meanY = w.reduce(0, +) / Double(n)

        let numerator = zip(t, w).reduce(0) { acc, pair in
            let (x, y) = pair
            return acc + (x - meanX) * (y - meanY)
        }

        let denominator = t.reduce(0) { acc, x in
            let dx = x - meanX
            return acc + dx * dx
        }
        return denominator != 0 ? numerator / denominator : 0
    }
}
