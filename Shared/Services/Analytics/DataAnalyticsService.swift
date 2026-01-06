import Foundation
import SwiftData
import SwiftUI

// MARK: - Data Analytics Service
// ============================================================================

/// Core analytics service implementing EWMA smoothing for intake data.
/// Used for both calorie tracking (28-day window) and macro tracking (7-day window).
public struct DataAnalyticsService: Sendable {
    /// Current day's intake values.
    let currentIntakes: [Date: Double]
    /// Historical daily intake values.
    let intakes: [Date: Double]
    /// EWMA smoothing factor (0.25 = 7-day equivalent).
    let alpha: Double
    /// Window size for confidence calculation (default: 28 days for calories).
    let windowDays: Int
    /// Minimum data points for full confidence (default: 14 for calories).
    let minDataPoints: Int

    /// Initialize with default parameters for calorie tracking (28-day window).
    public init(
        currentIntakes: [Date: Double],
        intakes: [Date: Double],
        alpha: Double
    ) {
        self.currentIntakes = currentIntakes
        self.intakes = intakes
        self.alpha = alpha
        self.windowDays = Int(RegressionWindowDays)
        self.minDataPoints = MinCalorieDataPoints
    }

    /// Initialize with custom window for macro tracking (typically 7-day window).
    public init(
        currentIntakes: [Date: Double],
        intakes: [Date: Double],
        alpha: Double,
        windowDays: Int,
        minDataPoints: Int
    ) {
        self.currentIntakes = currentIntakes
        self.intakes = intakes
        self.alpha = alpha
        self.windowDays = windowDays
        self.minDataPoints = minDataPoints
    }

    /// Daily intake totals grouped by date.
    var dailyIntakes: [Date: Double] {
        return intakes.bucketed(by: .day, using: .autoupdatingCurrent)
            .mapValues { $0.sum() }
    }

    /// Intakes within the configured window.
    private var windowIntakes: [Date: Double] {
        let cal = Calendar.autoupdatingCurrent
        let cutoff = Date().adding(-windowDays, .day, using: cal) ?? Date()
        return dailyIntakes.filter { $0.key >= cutoff }
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

    /// Number of distinct daily intake measurements in the window.
    public var dataPointCount: Int {
        windowIntakes.count
    }

    /// Span of calorie data in days within the window.
    private var dataSpanDays: Double {
        let sorted = windowIntakes.keys.sorted()
        guard let min = sorted.first, let max = sorted.last else { return 0 }
        return max.timeIntervalSince(min) / 86_400
    }

    /// Confidence factor (0-1) based on data quality within the window.
    /// Considers both density (points/minPoints) and span (span/windowDays).
    public var confidence: Double {
        let densityFactor = min(1.0, Double(dataPointCount) / Double(minDataPoints))
        let spanFactor = min(1.0, dataSpanDays / Double(windowDays))
        return densityFactor * spanFactor
    }

    /// Whether data has sufficient history for reliable smoothing.
    public var isValid: Bool {
        return dataPointCount >= minDataPoints
            && dataSpanDays >= Double(windowDays) * 0.5
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
