import Foundation
import HealthKit
import SwiftData

public struct BodyFatQuery: HealthQuery {
    public func save(_ data: BodyFatPercentage, store: HealthKitService) async throws {
        try await delete(data, store: store)

        let fraction = data.percentage / 100.0
        let quantity = HKQuantity(
            unit: HealthKitDataType.bodyFatPercentage.baseUnit,
            doubleValue: fraction
        )

        let sample = HKQuantitySample(
            type: HKQuantityType(.bodyFatPercentage), quantity: quantity,
            start: data.date, end: data.date
        )

        try await store.save(sample, of: sample.sampleType)
    }

    public func delete(_ data: BodyFatPercentage, store: HealthKitService) async throws {
        try await store.delete(
            data.id, of: HealthKitDataType.bodyFatPercentage.sampleType
        )
    }

    @MainActor public func fetch(
        from: Date, to: Date, limit: Int? = nil,
        store: HealthKitService
    ) async -> [BodyFatPercentage] {
        let samples = await store.fetchQuantitySamples(
            for: .bodyFatPercentage, from: from, to: to, limit: limit
        )

        let bodyFat = samples.map { sample in
            let fraction = sample.quantity.doubleValue(
                for: HealthKitDataType.bodyFatPercentage.baseUnit
            )
            let value = fraction * 100.0

            return BodyFatPercentage(
                value,
                id: sample.uuid,
                source: sample.sourceRevision.source.dataSource,
                date: sample.startDate,
            )
        }

        return bodyFat
    }
}
