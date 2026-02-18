import Foundation
import Observation
import SwiftUI
import WidgetKit

// MARK: - Budget Data Service
// ============================================================================

/// Observable service for budget data with automatic HealthKit integration
@Observable
public final class BudgetDataService: @unchecked Sendable {
    @MainActor public private(set) var budgetService: BudgetService?
    @MainActor public private(set) var isLoading: Bool = false

    // Injected dependencies
    private let healthKitService: HealthKitService
    private let adjustment: Double?
    private let date: Date
    private let logger = AppLogger.new(for: BudgetDataService.self)

    public init(
        healthKitService: HealthKitService? = nil,
        adjustment: Double? = nil,
        date: Date = Date()
    ) {
        self.healthKitService = healthKitService ?? HealthKitService.shared
        self.adjustment = adjustment
        self.date = date
        logger.info("BudgetDataService initialized")
    }

    // MARK: - Public Interface

    /// Refresh budget data from HealthKit
    @MainActor
    public func refresh() async {
        guard !isLoading else {
            logger.warning("Refresh already in progress")
            return
        }
        isLoading = true

        // Calculate date ranges for data fetching
        let cal = Calendar.autoupdatingCurrent
        let today = date.floored(to: .day, using: cal) ?? date
        let yesterday = today.adding(-1, .day, using: cal)

        // Rolling 7-day window: from 7 days ago to yesterday
        let rolling7DaysAgo = today.adding(-7, .day, using: cal)

        // Read user's first day of week setting for repayment schedule
        let storedWeekday: Weekday? = SharedDefaults.rawRepresentable(for: .firstDayOfWeek)
        let firstWeekday = storedWeekday?.calendarValue ?? cal.firstWeekday

        guard let ewmaRange = yesterday?.dateRange(by: 7, using: cal),
            let currentRange = today.dateRange(using: cal),
            let fittingRange = yesterday?.dateRange(
                by: RegressionWindowDays, using: cal),
            let rolling7DaysAgo = rolling7DaysAgo,
            let yesterday = yesterday
        else {
            logger.error("Failed to calculate date ranges for budget data")
            isLoading = false
            return
        }

        // Rolling 7-day range for credit (7 days ago to yesterday)
        let rollingRangeFrom = rolling7DaysAgo
        let rollingRangeTo = yesterday.ceiled(to: .day, using: cal) ?? yesterday

        // Fetch data for primary 28-day window and rolling credit

        let calorieData = await healthKitService.fetchStatistics(
            for: .dietaryCalories,
            from: ewmaRange.from, to: ewmaRange.to,
            interval: .daily,
            options: .cumulativeSum
        )

        let rollingCalorieData = await healthKitService.fetchStatistics(
            for: .dietaryCalories,
            from: rollingRangeFrom, to: rollingRangeTo,
            interval: .daily,
            options: .cumulativeSum
        )

        let maintenanceCalorieData = await healthKitService.fetchStatistics(
            for: .dietaryCalories,
            from: fittingRange.from, to: fittingRange.to,
            interval: .daily,
            options: .cumulativeSum
        )

        let currentCalorieData = await healthKitService.fetchStatistics(
            for: .dietaryCalories,
            from: currentRange.from, to: currentRange.to,
            interval: .daily,
            options: .cumulativeSum
        )

        let weightData = await healthKitService.fetchStatistics(
            for: .bodyMass,
            from: fittingRange.from, to: currentRange.to,
            interval: .daily,
            options: .discreteAverage
        )

        let bodyFatData = await healthKitService.fetchStatistics(
            for: .bodyFatPercentage,
            from: fittingRange.from, to: currentRange.to,
            interval: .daily,
            options: .discreteAverage
        )

        // Compute personal historical fallback maintenance via progressive fetch.
        // Expands the query window (6mo → 1yr → 2yr) until enough data is found.
        let historicalFallback = await computeHistoricalMaintenance(
            today: today, currentRange: currentRange,
            currentCalorieData: currentCalorieData,
            bodyFatPercentages: bodyFatData, calendar: cal
        )

        // Create primary 28-day maintenance service, blending toward
        // personal historical estimate (or BaselineMaintenance if no history)
        let weightAnalytics = MaintenanceService(
            calories: IntakeAnalyticsService(
                currentIntakes: currentCalorieData,
                intakes: maintenanceCalorieData,
                alpha: 0.25
            ),
            weights: weightData,
            bodyFatPercentages: bodyFatData,
            fallbackMaintenance: historicalFallback
        )

        // Create budget service with rolling 7-day credit and weekly repayment
        let newBudgetService = BudgetService(
            calories: IntakeAnalyticsService(
                currentIntakes: currentCalorieData,
                intakes: calorieData,
                alpha: 0.25
            ),
            weight: weightAnalytics,
            rollingIntakes: rollingCalorieData,
            adjustment: adjustment,
            firstWeekday: firstWeekday,
            currentDate: today
        )

        await MainActor.run {
            withAnimation(.default) {
                budgetService = newBudgetService
                isLoading = false
            }
        }

        logger.debug("Budget data refreshed")
    }

    /// Start observing HealthKit changes for automatic updates.
    /// Observation window covers the widest historical fetch stage to detect
    /// changes in data that could affect the historical maintenance fallback.
    public func startObserving(widgetId: String = "BudgetDataService") {
        let cal = Calendar.autoupdatingCurrent
        let maxStage = HistoricalFetchStages.last ?? RegressionWindowDays
        guard let currentRange = date.dateRange(using: cal),
            let historicalStart = date.adding(-Int(maxStage), .day, using: cal)
        else {
            logger.error("Failed to calculate date ranges for observation")
            return
        }

        // Use existing HealthKit observer infrastructure
        healthKitService.startObserving(
            for: widgetId, dataTypes: [.dietaryCalories, .bodyMass, .bodyFatPercentage],
            from: historicalStart, to: currentRange.to
        ) { [weak self] in
            Task {
                await self?.refresh()
            }
        }

        logger.info("Started observing HealthKit data for budget (widgetId: \(widgetId))")
    }

    /// Stop observing HealthKit changes
    public func stopObserving(widgetId: String = "BudgetDataService") {
        healthKitService.stopObserving(for: widgetId)
        logger.info("Stopped observing HealthKit data for budget")
    }

    // MARK: - Historical Maintenance

    /// Computes a personal historical maintenance estimate via progressive fetching.
    /// Queries progressively wider date ranges (6mo → 1yr → 2yr) until enough data
    /// is found (≥28 weight days AND ≥56 calorie days), then builds a
    /// `MaintenanceService` over that data. Returns `BaselineMaintenance` if no
    /// sufficient historical data exists.
    private func computeHistoricalMaintenance(
        today: Date, currentRange: (from: Date, to: Date),
        currentCalorieData: [Date: Double],
        bodyFatPercentages: [Date: Double],
        calendar cal: Calendar
    ) async -> Double {
        for stage in HistoricalFetchStages {
            guard let stageStart = today.adding(-Int(stage), .day, using: cal)
            else { continue }

            // Fetch historical data for this stage
            let historicalCalories = await healthKitService.fetchStatistics(
                for: .dietaryCalories,
                from: stageStart, to: currentRange.to,
                interval: .daily,
                options: .cumulativeSum
            )

            let historicalWeights = await healthKitService.fetchStatistics(
                for: .bodyMass,
                from: stageStart, to: currentRange.to,
                interval: .daily,
                options: .discreteAverage
            )

            let historicalBodyFat = await healthKitService.fetchStatistics(
                for: .bodyFatPercentage,
                from: stageStart, to: currentRange.to,
                interval: .daily,
                options: .discreteAverage
            )

            // Count actual data days (not calendar days)
            let calorieDataDays = historicalCalories.count
            let weightDataDays = historicalWeights.count

            // Check if we have enough data at this stage
            guard calorieDataDays >= MinHistoricalCalorieDataPoints,
                  weightDataDays >= MinHistoricalWeightDataPoints
            else {
                logger.debug(
                    "Historical stage \(stage)d: \(weightDataDays) weight, \(calorieDataDays) calorie days (insufficient)"
                )
                continue  // Expand to next stage
            }

            // Build historical maintenance service over the wider window
            let historicalService = MaintenanceService(
                calories: IntakeAnalyticsService(
                    currentIntakes: currentCalorieData,
                    intakes: historicalCalories,
                    alpha: 0.25,
                    windowDays: Int(stage),
                    minDataPoints: MinHistoricalCalorieDataPoints
                ),
                weights: historicalWeights,
                bodyFatPercentages: historicalBodyFat.isEmpty ? bodyFatPercentages : historicalBodyFat,
                windowDays: Int(stage),
                fallbackMaintenance: BaselineMaintenance
            )

            let historicalMaintenance = Int(historicalService.maintenance)
            let conf = String(format: "%.2f", historicalService.confidence)
            logger.info(
                "Historical maintenance from \(stage)d window: \(historicalMaintenance) kcal/day (conf: \(conf), \(weightDataDays)w \(calorieDataDays)c days)"
            )
            return historicalService.maintenance
        }

        logger.info("No sufficient historical data found, using baseline: \(Int(BaselineMaintenance)) kcal/day")
        return BaselineMaintenance
    }
}
