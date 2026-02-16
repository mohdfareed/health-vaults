import Foundation
import HealthKit
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

        // Fetch data

        let calorieData = await healthKitService.fetchStatistics(
            for: .dietaryCalories,
            from: ewmaRange.from, to: ewmaRange.to,
            interval: .daily,
            options: .cumulativeSum
        )

        // Fetch rolling 7-day intake for credit calculation
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

        // Fetch most recent body fat percentage from HealthKit
        let bodyFatData = await fetchLatestBodyFatPercentage()

        // Create analytics services

        let weightAnalytics = MaintenanceService(
            calories: IntakeAnalyticsService(
                currentIntakes: currentCalorieData,
                intakes: maintenanceCalorieData,
                alpha: 0.25  // 7 days - for smoothed intake in maintenance calc
            ),
            weights: weightData,
            bodyFatPercentage: bodyFatData
        )

        // Create budget service with rolling 7-day credit and weekly repayment
        let newBudgetService = BudgetService(
            calories: IntakeAnalyticsService(
                currentIntakes: currentCalorieData,
                intakes: calorieData,
                alpha: 0.25  // 7 days
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

    /// Start observing HealthKit changes for automatic updates
    public func startObserving(widgetId: String = "BudgetDataService") {
        let yesterday = date.adding(-1, .day, using: .autoupdatingCurrent)
        guard let currentRange = date.dateRange(using: .autoupdatingCurrent),
            let fittingRange = yesterday?.dateRange(
                by: RegressionWindowDays, using: .autoupdatingCurrent)
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

    /// Fetches the most recent body fat percentage from HealthKit.
    /// Returns a fraction (0-1), or nil if unavailable.
    private func fetchLatestBodyFatPercentage() async -> Double? {
        guard HealthKitService.isAvailable else { return nil }
        let type = HKQuantityType(.bodyFatPercentage)
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate, ascending: false
        )
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    AppLogger.new(for: BudgetDataService.self)
                        .warning("Failed to fetch body fat %: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sample.quantity.doubleValue(for: .percent())
                continuation.resume(returning: value)
            }
            healthKitService.store.execute(query)
        }
    }
}
