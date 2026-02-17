import Foundation
import SwiftData
import SwiftUI

// MARK: - Intake Analytics Service
// ============================================================================

/// Core analytics service implementing EWMA smoothing for intake data.
/// Used for both calorie tracking (28-day window) and macro tracking (7-day window).
public struct IntakeAnalyticsService: Sendable {
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

    /// Daily intakes sorted chronologically as (date, value) pairs.
    /// Only includes days with actual data — no gap filling.
    var sortedDailyIntakes: [(date: Date, value: Double)] {
        dailyIntakes.sorted { $0.key < $1.key }
            .map { (date: $0.key, value: $0.value) }
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

    /// EWMA-smoothed intake using configured alpha (for display, responsive).
    /// Gap-aware: scales effective alpha by gap size to properly decay across missing days.
    public var smoothedIntake: Double? {
        return computeEWMA(
            from: sortedDailyIntakes, alpha: alpha
        )
    }

    /// Long-term EWMA-smoothed intake using MaintenanceAlpha (for maintenance calc, stable).
    /// Ignores single-day spikes to provide stable baseline for TDEE estimation.
    /// Gap-aware: scales effective alpha by gap size to properly decay across missing days.
    public var longTermSmoothedIntake: Double? {
        return computeEWMA(
            from: sortedDailyIntakes, alpha: MaintenanceAlpha
        )
    }

    /// Total intake for current day.
    public var currentIntake: Double? {
        return currentIntakes.values.sum()
    }

    /// Computes gap-aware EWMA from dated data points.
    /// For a gap of n days between consecutive data points, the effective alpha
    /// is scaled: α_n = 1 - (1 - α)^n. This correctly decays the old smoothed
    /// value across the gap without fabricating intake data for missing days.
    /// - Parameters:
    ///   - entries: dated values [(date, value)] sorted oldest first
    ///   - alpha: base EWMA smoothing factor (0 < α < 1), applied per day
    /// - Returns: Sₜ where gaps properly decay the previous smoothed value
    func computeEWMA(from entries: [(date: Date, value: Double)], alpha: Double) -> Double? {
        guard let first = entries.first else { return nil }
        let cal = Calendar.autoupdatingCurrent

        var smoothed = first.value
        var previousDate = first.date

        for entry in entries.dropFirst() {
            // Calculate gap in days between this entry and the previous one
            let gap = max(1.0, entry.date.timeIntervalSince(previousDate) / 86_400)
            // Scale alpha by gap: α_n = 1 - (1 - α)^n
            // For gap=1 (consecutive days), this equals α (standard EWMA)
            // For larger gaps, more weight is given to the new value (old value decays more)
            let effectiveAlpha = 1.0 - pow(1.0 - alpha, gap)
            smoothed = effectiveAlpha * entry.value + (1.0 - effectiveAlpha) * smoothed
            previousDate = entry.date
        }
        return smoothed
    }
}
