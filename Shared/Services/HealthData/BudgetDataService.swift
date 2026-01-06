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
        let yesterday = date.adding(-1, .day, using: cal)
        let firstWeekday = Locale.autoupdatingCurrent.calendar.firstWeekday
        let weekStart = date.previous(firstWeekday, using: cal)

        guard let ewmaRange = yesterday?.dateRange(by: 7, using: cal),
            let currentRange = date.dateRange(using: cal),
            let fittingRange = yesterday?.dateRange(
                by: WeightRegressionDays, using: cal),
            let weekStart = weekStart,
            let yesterday = yesterday
        else {
            logger.error("Failed to calculate date ranges for budget data")
            isLoading = false
            return
        }

        // Calculate week range (week start to yesterday, for credit)
        // Only fetch if yesterday >= weekStart (i.e., not first day of week)
        let weekRangeFrom = weekStart
        let weekRangeTo = max(weekStart, yesterday.ceiled(to: .day, using: cal) ?? yesterday)

        // Fetch data

        let calorieData = await healthKitService.fetchStatistics(
            for: .dietaryCalories,
            from: ewmaRange.from, to: ewmaRange.to,
            interval: .daily,
            options: .cumulativeSum
        )

        // Fetch week's intake for credit calculation (week start to yesterday)
        let weekCalorieData: [Date: Double]
        if yesterday >= weekStart {
            weekCalorieData = await healthKitService.fetchStatistics(
                for: .dietaryCalories,
                from: weekRangeFrom, to: weekRangeTo,
                interval: .daily,
                options: .cumulativeSum
            )
        } else {
            weekCalorieData = [:]
        }

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

        // Create analytics services

        let weightAnalytics = WeightAnalyticsService(
            calories: DataAnalyticsService(
                currentIntakes: currentCalorieData,
                intakes: maintenanceCalorieData,
                alpha: 0.25  // 7 days - for smoothed intake in maintenance calc
            ),
            weights: weightData,
            rho: 7700  // Conservative: 7700 kcal/kg
        )

        // Create budget service with injected first weekday
        let newBudgetService = BudgetService(
            calories: DataAnalyticsService(
                currentIntakes: currentCalorieData,
                intakes: calorieData,
                alpha: 0.25  // 7 days
            ),
            weight: weightAnalytics,
            weekIntakes: weekCalorieData,
            adjustment: adjustment,
            firstWeekday: firstWeekday
        )

        await MainActor.run {
            withAnimation(.default) {
                budgetService = newBudgetService
                isLoading = false
            }
        }

        logger.debug("Budget data refreshed")
    }

    /// Start observing HealthKit changes for automatic updates
    public func startObserving(widgetId: String = "BudgetDataService") {
        let yesterday = date.adding(-1, .day, using: .autoupdatingCurrent)
        guard let currentRange = date.dateRange(using: .autoupdatingCurrent),
            let fittingRange = yesterday?.dateRange(
                by: WeightRegressionDays, using: .autoupdatingCurrent)
        else {
            logger.error("Failed to calculate date ranges for observation")
            return
        }

        let startDate = fittingRange.from
        let endDate = currentRange.to

        // Use existing HealthKit observer infrastructure
        healthKitService.startObserving(
            for: widgetId, dataTypes: [.dietaryCalories, .bodyMass],
            from: startDate, to: endDate
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
}
