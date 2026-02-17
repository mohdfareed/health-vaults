import Foundation
import HealthKit

// Enum to define the time interval for statistics queries
public enum StatisticsInterval: CaseIterable, Sendable {
    case hourly
    case daily
    case weekly
    case monthly

    // Provides the DateComponents for the HKStatisticsCollectionQuery
    var dateComponents: DateComponents {
        switch self {
        case .hourly:
            return DateComponents(hour: 1)
        case .daily:
            return DateComponents(day: 1)
        case .weekly:
            return DateComponents(weekOfYear: 1)
        case .monthly:
            return DateComponents(month: 1)
        }
    }

    // Calculates an anchor date for the query based on the interval type.
    func anchorDate(
        for referenceDate: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> Date {
        let component: Calendar.Component
        switch self {
        case .hourly:
            component = .hour
        case .daily:
            component = .day
        case .weekly:
            component = .weekOfYear
        case .monthly:
            component = .month
        }
        return referenceDate.floored(to: component, using: calendar)!
    }
}

extension HealthKitService {
    /// Fetches statistics for a given HealthKit data type.
    public func fetchStatistics(
        for type: HealthKitDataType,
        from startDate: Date, to endDate: Date,
        interval: StatisticsInterval,
        options: HKStatisticsOptions
    ) async -> [Date: Double] {
        guard Self.isAvailable else { return [:] }
        let quantityType = type.quantityType
        let resultUnit = getTargetUnit(for: type)
        let calendar = Calendar.current

        // Use the startDate of the query range to determine the anchor.
        let anchorDate = interval.anchorDate(for: startDate, calendar: calendar)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: nil,
                options: options,
                anchorDate: anchorDate,
                intervalComponents: interval.dateComponents
            )

            query.initialResultsHandler = { [weak self] _, collection, error in
                guard let self = self else {
                    continuation.resume(returning: [:])
                    return
                }

                if let error = error {
                    let id = quantityType.identifier
                    let msg = error.localizedDescription

                    self.logger.error(
                        "Failed to fetch statistics for \(id): \(msg)"
                    )
                    continuation.resume(returning: [:])
                    return
                }

                var results: [Date: Double] = [:]
                // Enumerate through the statistics, ensuring the range matches the query.
                collection?.enumerateStatistics(
                    from: startDate, to: endDate
                ) { statistics, stop in
                    var value: Double?

                    // Extract value based on the primary HKStatisticsOptions
                    if options.contains(.cumulativeSum) {
                        value = statistics.sumQuantity()?
                            .doubleValue(for: resultUnit)
                    } else if options.contains(.discreteAverage) {
                        value = statistics.averageQuantity()?
                            .doubleValue(for: resultUnit)
                    } else if options.contains(.discreteMin) {
                        value = statistics.minimumQuantity()?
                            .doubleValue(for: resultUnit)
                    } else if options.contains(.discreteMax) {
                        value = statistics.maximumQuantity()?
                            .doubleValue(for: resultUnit)
                    } else if options.contains(.duration) {
                        value = statistics.duration()?
                            .doubleValue(for: resultUnit)
                    } else if options.contains(.mostRecent) {
                        value = statistics.mostRecentQuantity()?
                            .doubleValue(for: resultUnit)
                    } else {  // Default to cumulative sum
                        value = statistics.sumQuantity()?
                            .doubleValue(for: resultUnit)
                    }

                    if let value {
                        results[statistics.startDate] = value
                    }
                }
                continuation.resume(returning: results)
            }
            self.store.execute(query)
        }
    }
}

extension HealthKitService {
    private func getTargetUnit(for type: HealthKitDataType) -> HKUnit {
        switch type {
        case .dietaryCalories: .kilocalorie()
        case .protein, .carbs, .fat: .gram()
        case .bodyMass: .gramUnit(with: .kilo)
        case .alcohol: .count()
        }
    }
}
