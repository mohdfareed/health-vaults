import HealthKit
import SwiftData
import SwiftUI

// MARK: - Period Grouping
// ============================================================================

/// Time periods for grouping records.
enum RecordPeriod: String, CaseIterable, Identifiable {
    case all = "All"
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }

    var calendarComponent: Calendar.Component? {
        switch self {
        case .all: nil
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }
}

/// A bucket of records grouped by a time period.
struct RecordBucket<T: HealthData>: Identifiable {
    let id: Date // bucket start date
    let records: [T]
    let aggregation: AggregationType

    var aggregate: Double {
        guard !records.isEmpty else { return 0 }
        let values = records.map(\.value)
        switch aggregation {
        case .sum: return values.reduce(0, +)
        case .average: return values.reduce(0, +) / Double(values.count)
        }
    }

    var count: Int { records.count }
}

// MARK: - Record List
// ============================================================================

/// A view that displays records of a specific type with source filtering.
struct RecordList<T: HealthData>: View {
    @DataQuery var records: [T]
    @State private var isCreating = false
    @State private var selectedPeriod: RecordPeriod = .all
    @Environment(\.healthKit) private var healthKit
    @AppLocale private var locale

    private let dataModel: HealthDataModel
    private let definition: RecordDefinition
    private let healthKitDataTypes: [HealthKitDataType]

    private var hasPermission: Bool {
        healthKitDataTypes.allSatisfy {
            healthKit.isAuthorized(for: $0.sampleType) == .sharingAuthorized
        }
    }

    init(_ dataModel: HealthDataModel, for: T.Type) {
        self.dataModel = dataModel
        self.definition = dataModel.definition

        let query: any HealthQuery<T> = dataModel.query()
        _records = DataQuery(
            query, from: .distantPast, to: .distantFuture
        )

        // Map data model to HealthKit data types for change observation
        switch dataModel {
        case .weight:
            self.healthKitDataTypes = [.bodyMass]
        case .calorie:
            self.healthKitDataTypes = [.dietaryCalories]
        case .bodyFat:
            self.healthKitDataTypes = [.bodyFatPercentage]
        }
    }

    var body: some View {
        List {
            if !records.isEmpty || $records.isLoading {
                Section {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(RecordPeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if selectedPeriod == .all {
                    flatRecordsList
                } else {
                    bucketedRecordsList
                }

                loadMoreButton()
            }
        }
        #if os(iOS)
        .listSectionSpacing(.compact)
        #endif
        .overlay {
            if records.isEmpty && !$records.isLoading {
                if hasPermission {
                    ContentUnavailableView(
                        "No Records Yet",
                        systemImage: "tray",
                        description: Text("Add a new record to get started.")
                    )
                } else {
                    ContentUnavailableView(
                        "Health Access Needed",
                        systemImage: "heart.slash",
                        description: Text(
                            "This list is empty because Apple Health permission is not granted for this data type."
                        )
                    )
                }
            }
        }
        .navigationTitle(String(localized: definition.title))
        .animation(.default, value: selectedPeriod)
        .animation(.default, value: records.isEmpty)

        .task {
            await $records.reload()
        }
        .refreshable {
            await $records.reload()
        }
        .refreshOnHealthDataChange(for: healthKitDataTypes) {
            await $records.reload()
        }

        .toolbar {
            ToolbarItem {
                Button("Add", systemImage: "plus") {
                    isCreating = true
                }
            }
        }

        .sheet(isPresented: $isCreating) {
            NavigationStack {
                dataModel.createForm(formType: .create)
            }
        }
    }

    // MARK: - Flat Records List

    @ViewBuilder private var flatRecordsList: some View {
        ForEach(records) { record in
            RecordListRow(record: record, definition: definition)
                .swipeActions {
                    if record.source == .app {
                        Button(role: .destructive) {
                            delete(record)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
        }
    }

    // MARK: - Bucketed Records List

    private var buckets: [RecordBucket<T>] {
        guard let component = selectedPeriod.calendarComponent else { return [] }
        let calendar = locale.calendar

        let grouped = Dictionary(grouping: records) { record in
            calendar.dateInterval(of: component, for: record.date)?.start ?? record.date
        }

        return grouped.map { (start, items) in
            RecordBucket(
                id: start,
                records: items.sorted { $0.date > $1.date },
                aggregation: dataModel.aggregation
            )
        }
        .sorted { $0.id > $1.id }
    }

    @ViewBuilder private var bucketedRecordsList: some View {
        ForEach(buckets) { bucket in
            NavigationLink {
                BucketDetailView(
                    bucket: bucket,
                    period: selectedPeriod,
                    dataModel: dataModel,
                    definition: definition,
                    healthKitDataTypes: healthKitDataTypes,
                    onDelete: delete
                )
            } label: {
                BucketRow(
                    bucket: bucket,
                    period: selectedPeriod,
                    dataModel: dataModel,
                    definition: definition
                )
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder private func loadMoreButton() -> some View {
        if !$records.isLoading && !$records.isExhausted {
            Button("Show More") {
                Task { await $records.loadNextPage() }
            }
            .frame(maxWidth: .infinity)
        }

        if $records.isLoading {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
    }

    private func delete(_ record: T) {
        // Optimistically remove from local state immediately
        $records.removeItem(record)

        // Then delete from backend
        Task {
            do {
                try await dataModel.query().delete(record, store: healthKit)
                // Notify that data changed so other views can update
                HealthDataNotifications.shared.notifyDataChanged(for: healthKitDataTypes)
            } catch {
                // On error, reload to restore the item
                AppLogger.new(for: record).error("Failed to delete record: \(error)")
                await $records.reload()
            }
        }
    }
}

// MARK: - Bucket Row
// ============================================================================

private struct BucketRow<T: HealthData>: View {
    @AppLocale private var locale
    let bucket: RecordBucket<T>
    let period: RecordPeriod
    let dataModel: HealthDataModel
    let definition: RecordDefinition

    var body: some View {
        LabeledContent {
            HStack(alignment: .center, spacing: 8) {
                Text(formatBucketDate(bucket.id))
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("\(bucket.count)")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        } label: {
            definition.aggregateView(bucket.aggregate)
        }
    }

    private func formatBucketDate(_ date: Date) -> String {
        let calendar = locale.calendar
        switch period {
        case .all:
            return ""
        case .day:
            return date.formatted(.dateTime.month(.abbreviated).day().year())
        case .week:
            let end = calendar.date(byAdding: .day, value: 6, to: date) ?? date
            let startStr = date.formatted(.dateTime.month(.abbreviated).day())
            let endStr = end.formatted(.dateTime.month(.abbreviated).day().year())
            return "\(startStr) – \(endStr)"
        case .month:
            return date.formatted(.dateTime.month(.wide).year())
        }
    }
}

// MARK: - Bucket Detail View
// ============================================================================

private struct BucketDetailView<T: HealthData>: View {
    @AppLocale private var locale
    @Environment(\.healthKit) private var healthKit

    let bucket: RecordBucket<T>
    let period: RecordPeriod
    let dataModel: HealthDataModel
    let definition: RecordDefinition
    let healthKitDataTypes: [HealthKitDataType]
    let onDelete: (T) -> Void

    @State private var isCreating = false

    /// Default date for new entries: end of bucket range or today, whichever is earlier.
    private var defaultDate: Date {
        guard let component = period.calendarComponent,
              let interval = locale.calendar.dateInterval(of: component, for: bucket.id)
        else { return Date() }
        // Last moment of the bucket range, but never in the future
        let bucketEnd = interval.end.addingTimeInterval(-1)
        return min(bucketEnd, Date())
    }

    var body: some View {
        List {
            Section {
                LabeledContent {
                    definition.aggregateView(bucket.aggregate)
                } label: {
                    Text(dataModel.aggregation.label)
                }

                if period == .week || period == .month {
                    LabeledContent {
                        definition.aggregateView(dailyAverage)
                    } label: {
                        Text("Daily Average")
                    }
                }

                if period == .month {
                    LabeledContent {
                        definition.aggregateView(weeklyAverage)
                    } label: {
                        Text("Weekly Average")
                    }
                }
            }

            Section {
                ForEach(bucket.records) { record in
                    RecordListRow(record: record, definition: definition)
                        .swipeActions {
                            if record.source == .app {
                                Button(role: .destructive) {
                                    onDelete(record)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                }
            }
        }
        .navigationTitle(bucketTitle)
        .toolbar {
            ToolbarItem {
                Button("Add", systemImage: "plus") {
                    isCreating = true
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            NavigationStack {
                dataModel.createForm(formType: .create, defaultDate: defaultDate)
            }
        }
    }

    private var bucketTitle: String {
        let calendar = locale.calendar
        switch period {
        case .all:
            return String(localized: definition.title)
        case .day:
            return bucket.id.formatted(.dateTime.month(.abbreviated).day().year())
        case .week:
            let end = calendar.date(byAdding: .day, value: 6, to: bucket.id) ?? bucket.id
            let startStr = bucket.id.formatted(.dateTime.month(.abbreviated).day())
            let endStr = end.formatted(.dateTime.month(.abbreviated).day())
            return "\(startStr) – \(endStr)"
        case .month:
            return bucket.id.formatted(.dateTime.month(.wide).year())
        }
    }

    /// Average value per day within this bucket.
    private var dailyAverage: Double {
        let calendar = locale.calendar
        let grouped = Dictionary(grouping: bucket.records) {
            calendar.startOfDay(for: $0.date)
        }
        guard !grouped.isEmpty else { return 0 }

        let dailyValues = grouped.values.map { dayRecords in
            let values = dayRecords.map(\.value)
            switch dataModel.aggregation {
            case .sum: return values.reduce(0, +)
            case .average: return values.reduce(0, +) / Double(values.count)
            }
        }
        return dailyValues.reduce(0, +) / Double(dailyValues.count)
    }

    /// Average value per week within this bucket (monthly only).
    private var weeklyAverage: Double {
        let calendar = locale.calendar
        let grouped = Dictionary(grouping: bucket.records) {
            calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start ?? $0.date
        }
        guard !grouped.isEmpty else { return 0 }

        let weeklyValues = grouped.values.map { weekRecords in
            let values = weekRecords.map(\.value)
            switch dataModel.aggregation {
            case .sum: return values.reduce(0, +)
            case .average: return values.reduce(0, +) / Double(values.count)
            }
        }
        return weeklyValues.reduce(0, +) / Double(weeklyValues.count)
    }
}

// MARK: - Record Row
// ============================================================================

private struct RecordListRow: View {
    @AppLocale private var locale
    @State var record: any HealthData
    let definition: RecordDefinition

    var body: some View {
        NavigationLink {
            let dataModel = HealthDataModel.from(record)
            dataModel.createForm(
                formType: record.source == .app ? .edit : .view,
                record: record
            )
        } label: {
            LabeledContent {
                HStack(alignment: .center, spacing: 6) {
                    Text(record.date, format: shortDateFormat)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                    record.source.icon.asText
                        .foregroundColor(record.source.color)
                        .font(.footnote)
                }
            } label: {
                definition.rowView(record)
            }
        }
    }

    private var shortDateFormat: Date.FormatStyle {
        let cal = locale.calendar
        let isSameYear = cal.isDate(record.date, equalTo: Date(), toGranularity: .year)
        let isToday = cal.isDateInToday(record.date)

        if isToday {
            return .dateTime.hour().minute()
        } else if isSameYear {
            return .dateTime.month(.abbreviated).day()
        } else {
            return .dateTime.month(.abbreviated).day().year(.twoDigits)
        }
    }
}

// MARK: Add Buttons
// ============================================================================

public struct AddMenu: View {
    let action: (HealthDataModel) -> Void
    public init(_ action: @escaping (HealthDataModel) -> Void) {
        self.action = action
    }

    public var body: some View {
        Menu {
            ForEach(HealthDataModel.allCases, id: \.self) { dataModel in
                Button(action: { action(dataModel) }) {
                    Label {
                        Text(String(localized: dataModel.definition.title))
                    } icon: {
                        dataModel.definition.icon
                    }
                }
            }
        } label: {
            Label("Add Data", systemImage: "plus")
                .labelStyle(.iconOnly)
                .font(.title2)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
    }
}

public struct AddButton: View {
    @Environment(\.tabViewBottomAccessoryPlacement) var placement

    let definition: RecordDefinition
    let action: () -> Void

    public init(_ definition: RecordDefinition, action: @escaping () -> Void) {
        self.definition = definition
        self.action = action
    }

    public var body: some View {
        switch placement {
        case .inline:
            inlineButton
        case .expanded:
            expandedButton
        default:  // expanded
            let _ = AppLogger.new(for: self).warning(
                "Unsupported button placement: \(placement.debugDescription)"
            )
            expandedButton
        }
    }

    var inlineButton: some View {
        Button(action: { action() }) {
            definition.icon
        }
        .buttonStyle(.borderless)
        .labelStyle(.titleAndIcon)
        .foregroundStyle(definition.color)
        .padding(.horizontal)
    }

    var expandedButton: some View {
        Button(action: { action() }) {
            Label {
                Text(String(localized: definition.title))
            } icon: {
                definition.icon
            }
        }
        .glassEffect(
            .regular.tint(definition.color)
        )
        .buttonStyle(.glass)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal)
    }
}
