import HealthKit
import HealthVaultsShared
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Budget Widget
// ============================================================================

struct BudgetWidget: Widget {
    let kind: String = BudgetWidgetID

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: BudgetTimelineProvider()
        ) { entry in
            BudgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Budget")
        .description("Track your daily calorie budget")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BudgetWidgetEntryView: View {
    var entry: BudgetEntry

    var body: some View {
        content
            .background(Color.clear)
            .widgetBackground()
    }

    @ViewBuilder
    private var content: some View {
        if let budgetService = entry.budgetService {
            BudgetComponent(preloadedBudgetService: budgetService)
                .fontDesign(.rounded)
        } else {
            VStack {
                Image(systemName: "chart.pie.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Budget Timeline Provider
// ============================================================================

struct BudgetTimelineProvider: AppIntentTimelineProvider {
    @AppStorage(.userGoals) private var goalsID: UUID

    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: Date(), budgetService: nil, configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async
        -> BudgetEntry
    {
        await generateEntry(for: Date(), configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<
        BudgetEntry
    > {
        let currentDate = Date()
        let entry = await generateEntry(for: currentDate, configuration: configuration)

        // Schedule next update in 1 hour to refresh the data
        let nextUpdate =
            Calendar.current.date(byAdding: .hour, value: 1, to: currentDate) ?? currentDate

        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    @MainActor
    private func generateEntry(for date: Date, configuration: ConfigurationAppIntent) async
        -> BudgetEntry
    {
        // Ensure HealthKit observer is running in widget process
        await AppHealthKitObserver.shared.startObserving()

        // Get current adjustment from UserGoals using shared helper
        let goals = await WidgetsSettings.getGoals(for: goalsID)

        // Create the data service with proper settings
        let budgetDataService = BudgetDataService(
            adjustment: goals?.adjustment,
            date: date
        )

        // Load the data
        await budgetDataService.refresh()

        return BudgetEntry(
            date: date,
            budgetService: budgetDataService.budgetService,
            configuration: configuration
        )
    }
}

struct BudgetEntry: TimelineEntry, Sendable {
    let date: Date
    let budgetService: BudgetService?
    let configuration: ConfigurationAppIntent
}
