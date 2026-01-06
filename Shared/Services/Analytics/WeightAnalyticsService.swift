import Foundation
import SwiftData
import SwiftUI
import WidgetKit

// TODO: Implement body-fat percentage calculations to implement
// Hall’s NIH dynamic model of energy imbalance

/// Weight analytics service for maintenance calorie estimation.
/// Implements linear regression on weight trends to estimate energy balance.
///
/// ## Algorithm
/// Uses a unified 28-day window for both regression and confidence:
/// 1. Linear regression on weight data within the window → raw slope
/// 2. Raw maintenance = EWMA(intake) - (slope × ρ / 7)
/// 3. Confidence = (points/minPoints) × (span/windowDays)
/// 4. Final maintenance = raw × confidence + baseline × (1 - confidence)
///
/// Only the final maintenance is blended toward baseline; the slope is
/// clamped for safety but not damped, preserving the true trend signal.
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

    /// Raw weight slope from linear regression (kg/week).
    public var rawWeightSlope: Double {
        return computeSlope * 7
    }

    /// Raw maintenance estimate before confidence blending (kcal/day).
    public var rawMaintenance: Double {
        guard let smoothed = calories.smoothedIntake else {
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

    /// Computes the slope (kg/day) using least-squares linear regression
    /// on data within the regression window.
    private var computeSlope: Double {
        let sorted = windowWeights.sorted { $0.key < $1.key }
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
