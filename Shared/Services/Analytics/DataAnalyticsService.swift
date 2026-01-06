import Foundation
import SwiftData
import SwiftUI

// MARK: - Data Analytics Service
// ============================================================================

/// Core analytics service implementing EWMA smoothing for calorie data.
public struct DataAnalyticsService: Sendable {
    /// Current day's intake values (kcal).
    let currentIntakes: [Date: Double]
    /// Historical daily intake values (kcal).
    let intakes: [Date: Double]
    /// EWMA smoothing factor (0.25 = 7-day equivalent).
    let alpha: Double

    /// Daily intake totals grouped by date.
    var dailyIntakes: [Date: Double] {
        return intakes.bucketed(by: .day, using: .autoupdatingCurrent)
            .mapValues { $0.sum() }
    }

    /// Daily intakes with missing days filled using the average of existing values.
    /// This prevents gaps in data from skewing EWMA calculations.
    var dailyIntakesWithMissingDays: [Double] {
        guard let range = intakeDateRange else { return [] }

        let calendar = Calendar.autoupdatingCurrent
        let average = dailyIntakes.values.average() ?? 0
        var current = range.from
        var values: [Double] = []

        // Walk through each day in the range and fill missing days with average
        while current <= range.to {
            let floored = current.floored(to: .day, using: calendar) ?? current
            if let value = dailyIntakes[floored] {
                values.append(value)
            } else {
                values.append(average)
            }
            current = current.adding(1, .day, using: calendar) ?? current
        }

        return values
    }

    /// Date range covered by historical intake data.
    var intakeDateRange: (from: Date, to: Date)? {
        let max = dailyIntakes.keys.sorted().max()
        let min = dailyIntakes.keys.sorted().min()
        guard let max: Date = max, let min: Date = min else { return nil }
        return (from: min, to: max)
    }

    /// Date range covered by current intake data.
    var currentIntakeDateRange: (from: Date, to: Date)? {
        let max = currentIntakes.keys.sorted().max()
        let min = currentIntakes.keys.sorted().min()
        guard let max: Date = max, let min: Date = min else { return nil }
        return (from: min, to: max)
    }

    /// Number of distinct daily intake measurements.
    public var dataPointCount: Int {
        dailyIntakes.count
    }

    /// Data span in days between first and last intake measurement.
    public var dataSpanDays: Int {
        guard let range = intakeDateRange else { return 0 }
        return range.from.distance(
            to: range.to, in: .day, using: .autoupdatingCurrent
        ) ?? 0
    }

    /// Confidence factor (0-1) based on calorie data quality.
    /// Low confidence indicates EWMA hasn't converged yet.
    public var confidence: Double {
        let pointConfidence = min(1.0, Double(dataPointCount) / Double(MinCalorieDataPoints))
        let spanConfidence = min(1.0, Double(dataSpanDays) / Double(MinCalorieSpanDays))
        return pointConfidence * spanConfidence
    }

    /// Whether calorie data has sufficient history for reliable smoothing.
    public var isValid: Bool {
        return dataPointCount >= MinCalorieDataPoints && dataSpanDays >= MinCalorieSpanDays
    }

    /// EWMA-smoothed intake: S_t = α·C_{t-1} + (1-α)·S_{t-1}.
    /// Uses average for missing days to prevent data gaps from skewing results.
    public var smoothedIntake: Double? {
        return computeEWMA(
            from: dailyIntakesWithMissingDays, alpha: alpha
        )
    }

    /// Total intake for current day.
    public var currentIntake: Double? {
        return currentIntakes.values.sum()
    }

    /// Computes EWMA from time series data points.
    /// - Parameters:
    ///   - values: historical values [C₀, C₁, …, Cₜ₋₁] (oldest first)
    ///   - alpha: EWMA smoothing factor (0 < α < 1)
    /// - Returns: Sₜ where
    ///   S₀ = C₀
    ///   Sᵢ = α·Cᵢ + (1−α)·Sᵢ₋₁
    func computeEWMA(from values: [Double], alpha: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        // Seed with the first data point
        var smoothed = values[0]
        // Fold over the rest (last has highest weight)
        for value in values.dropFirst() {
            smoothed = alpha * value + (1 - alpha) * smoothed
        }
        return smoothed
    }
}
