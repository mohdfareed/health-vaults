import Foundation
import SwiftData
import SwiftUI

extension HealthDataModel {
    public var id: Self { self }

    /// All the health data types supported by the app.
    static var allTypes: [any HealthData.Type] {
        allCases.map { $0.dataType }
    }

    /// Gets the appropriate query for this data type
    @MainActor func query<T: HealthData>() -> any HealthQuery<T> {
        switch self {
        case .weight:
            return WeightQuery() as! any HealthQuery<T>
        case .calorie:
            return DietaryQuery() as! any HealthQuery<T>
        }
    }
}

// MARK: Data Query
// ============================================================================

/// A property wrapper that paginates HealthKit data queries.
@MainActor @propertyWrapper
public struct DataQuery<T>: DynamicProperty
where T: HealthData {
    @Environment(\.healthKit)
    private var healthKitService

    private let query: any HealthQuery<T>
    private let dateRange: ClosedRange<Date>
    private let pageSize: Int

    @State private var items: [T] = []  // Aggregated, paged items
    @State private var cursorDate: Date? = nil  // Pagination cursor

    @State var isLoading = false
    @State var isExhausted = false

    public var wrappedValue: [T] {
        items.sorted { $0.date > $1.date }
    }
    public var projectedValue: Self { self }

    public init<Q>(
        _ query: Q,
        from start: Date? = nil, to end: Date? = nil, limit: Int = 50
    ) where Q: HealthQuery<T> {
        self.query = query
        self.dateRange = .init(from: start, to: end)
        self.pageSize = limit
    }
}

// MARK: Data Loading
// ============================================================================

extension DataQuery {
    func reload() async {
        guard !isLoading else { return }

        // Reset pagination state
        cursorDate = nil
        // Load first page
        let page = await loadPage([])
        items = page
    }

    func loadNextPage() async {
        guard !isLoading, !isExhausted else { return }

        // Append the next page of items
        let page = await loadPage(items)
        items.append(contentsOf: page)
    }

    /// Removes an item from the local state without reloading.
    /// Used for optimistic updates during delete operations.
    func removeItem(_ item: T) {
        items.removeAll { $0.id == item.id }
    }

    func loadPage(_ current: [T]) async -> [T] {
        defer { isLoading = false }
        isLoading = true

        // 1) Determine bounds for this page
        // For chronological pagination (newest first),
        // we paginate backwards from cursorDate
        let toDate = cursorDate ?? dateRange.upperBound
        let fromDate = dateRange.lowerBound

        // 2) Fetch HealthKit chunk
        var remoteChunk: [T] = []
        if HealthKitService.isAvailable {
            remoteChunk = await query.fetch(
                from: fromDate, to: toDate, limit: pageSize,
                store: healthKitService
            )
        }

        // 3) Filter out items we already have and sort by date descending
        let existingDates = Set(current.map { $0.date })
        let filteredChunk =
            remoteChunk
            .filter { !existingDates.contains($0.date) }
            .sorted { $0.date > $1.date }

        // 4) Take up to pageSize items
        let page = Array(filteredChunk.prefix(pageSize))

        // 5) Check if we've reached the end
        if page.isEmpty || page.count < pageSize {
            isExhausted = true
        }

        // 7) Update cursor to just before the oldest item in this page
        if let oldest = page.last {
            cursorDate = oldest.date.addingTimeInterval(-0.001)
        }

        return page
    }
}

// MARK: Extensions
// ============================================================================

extension ClosedRange<Date> {
    init(from start: Bound?, to end: Bound?) {
        let start = start ?? .distantPast
        let end = end ?? .distantFuture
        self = start...end
    }
}
