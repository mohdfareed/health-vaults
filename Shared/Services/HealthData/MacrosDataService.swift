import Foundation
import Observation
import SwiftUI
import WidgetKit

// MARK: - Macros Data Service
// ============================================================================

/// Observable service for macros data with automatic HealthKit integration
@Observable
public final class MacrosDataService: @unchecked Sendable {
    @MainActor public private(set) var macrosService: MacrosAnalyticsService?
    @MainActor public private(set) var isLoading: Bool = false

    // Injected dependencies
    private let healthKitService: HealthKitService
    private let budgetService: BudgetService?
    private let adjustments: CalorieMacros?
    private let date: Date

    private let logger = AppLogger.new(for: MacrosDataService.self)

    public init(
        healthKitService: HealthKitService? = nil,
        budgetService: BudgetService? = nil,
        adjustments: CalorieMacros? = nil,
        date: Date = Date()
    ) {
        self.healthKitService = healthKitService ?? HealthKitService.shared
        self.budgetService = budgetService
        self.adjustments = adjustments
        self.date = date
        logger.info("MacrosDataService initialized")
    }

    // MARK: - Public Interface

    /// Refresh macros data from HealthKit.
    @MainActor
    public func refresh() async {
        guard !isLoading else {
            logger.warning("Refresh already in progress")
            return
        }
        isLoading = true

        // Calculate date ranges for data fetching
        let yesterday = date.adding(-1, .day, using: .autoupdatingCurrent)

        guard let ewmaRange = yesterday?.dateRange(by: 7, using: .autoupdatingCurrent),
            let currentRange = date.dateRange(using: .autoupdatingCurrent)
        else {
            logger.error("Failed to calculate date ranges for macros data")
            isLoading = false
            return
        }

        // Fetch macro-nutrient data
        let proteinData = await healthKitService.fetchStatistics(
            for: .protein,
            from: ewmaRange.from, to: ewmaRange.to,
            interval: .daily,
            options: .cumulativeSum
        )

        let currentProteinData = await healthKitService.fetchStatistics(
            for: .protein,
            from: currentRange.from, to: currentRange.to,
            interval: .daily,
            options: .cumulativeSum
        )

        let carbsData = await healthKitService.fetchStatistics(
            for: .carbs,
            from: ewmaRange.from, to: ewmaRange.to,
            interval: .daily,
            options: .cumulativeSum
        )

        let currentCarbsData = await healthKitService.fetchStatistics(
            for: .carbs,
            from: currentRange.from, to: currentRange.to,
            interval: .daily,
            options: .cumulativeSum
        )

        let fatData = await healthKitService.fetchStatistics(
            for: .fat,
            from: ewmaRange.from, to: ewmaRange.to,
            interval: .daily,
            options: .cumulativeSum
        )

        let currentFatData = await healthKitService.fetchStatistics(
            for: .fat,
            from: currentRange.from, to: currentRange.to,
            interval: .daily,
            options: .cumulativeSum
        )

        // Create analytics services for each macro-nutrient
        // Use 7-day window with 4 data points minimum (lighter than calorie requirements)
        let proteinAnalytics = IntakeAnalyticsService(
            currentIntakes: currentProteinData,
            intakes: proteinData,
            alpha: 0.25,
            windowDays: 7,
            minDataPoints: 4
        )

        let carbsAnalytics = IntakeAnalyticsService(
            currentIntakes: currentCarbsData,
            intakes: carbsData,
            alpha: 0.25,
            windowDays: 7,
            minDataPoints: 4
        )

        let fatAnalytics = IntakeAnalyticsService(
            currentIntakes: currentFatData,
            intakes: fatData,
            alpha: 0.25,
            windowDays: 7,
            minDataPoints: 4
        )

        // Create macros analytics service
        let newMacrosService = MacrosAnalyticsService(
            calories: budgetService,
            protein: proteinAnalytics,
            carbs: carbsAnalytics,
            fat: fatAnalytics,
            adjustments: adjustments,
        )

        await MainActor.run {
            withAnimation(.default) {
                macrosService = newMacrosService
                isLoading = false
            }
        }
        logger.debug("Macros data refreshed")
    }

    /// Start observing HealthKit changes for automatic updates
    public func startObserving(widgetId: String = "MacrosDataService") {
        let yesterday = date.adding(-1, .day, using: .autoupdatingCurrent)
        guard let currentRange = date.dateRange(using: .autoupdatingCurrent),
            let ewmaRange = yesterday?.dateRange(by: 7, using: .autoupdatingCurrent)
        else {
            logger.error("Failed to calculate date ranges for observation")
            return
        }

        let startDate = ewmaRange.from
        let endDate = currentRange.to

        // Use existing HealthKit observer infrastructure
        healthKitService.startObserving(
            for: widgetId, dataTypes: [.protein, .carbs, .fat],
            from: startDate, to: endDate
        ) { [weak self] in
            Task {
                await self?.refresh()
            }
        }

        logger.info("Started observing HealthKit data for macros (widgetId: \(widgetId))")
    }

    /// Stop observing HealthKit changes
    public func stopObserving(widgetId: String = "MacrosDataService") {
        healthKitService.stopObserving(for: widgetId)
        logger.info("Stopped observing HealthKit data for macros")
    }
}

// MARK: - Supporting Types
// ============================================================================

extension CalorieMacros {
    var description: String {
        return
            "protein: \(protein?.description ?? "nil"), carbs: \(carbs?.description ?? "nil"), fat: \(fat?.description ?? "nil")"
    }
}
