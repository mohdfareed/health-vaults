import HealthKit
import HealthVaultsShared
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Macros Widget
// ============================================================================

struct MacrosWidget: Widget {
    let kind: String = MacrosWidgetID

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: MacroSelectionAppIntent.self,
            provider: MacrosTimelineProvider()
        ) { entry in
            MacrosWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Macros")
        .description("Track your daily macro-nutrient intake")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MacrosWidgetEntryView: View {
    var entry: MacrosEntry

    var body: some View {
        content
            .background(Color.clear)
            .widgetBackground()
    }

    @ViewBuilder
    private var content: some View {
        if let macrosService = entry.macrosService {
            MacrosComponent(
                selectedMacro: entry.configuration.macroType.sharedMacroType,
                preloadedMacrosService: macrosService
            )
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

// MARK: - Macros Timeline Provider
// ============================================================================

struct MacrosTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MacrosEntry {
        return MacrosEntry(
            date: Date(), macrosService: nil, configuration: MacroSelectionAppIntent())
    }

    func snapshot(for configuration: MacroSelectionAppIntent, in context: Context) async
        -> MacrosEntry
    {
        return await generateEntry(for: Date(), configuration: configuration)
    }

    func timeline(
        for configuration: MacroSelectionAppIntent, in context: Context
    ) async -> Timeline<MacrosEntry> {
        let currentDate = Date()
        let entry = await generateEntry(for: currentDate, configuration: configuration)

        // Schedule next update in 1 hour to refresh the data (same as BudgetWidget)
        let nextUpdate =
            Calendar.current.date(byAdding: .hour, value: 1, to: currentDate) ?? currentDate

        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    @MainActor
    private func generateEntry(for date: Date, configuration: MacroSelectionAppIntent) async
        -> MacrosEntry
    {
        // Get current macros and adjustment from UserGoals using shared helper
        let goals = await WidgetsSettings.getGoals()

        // Create the budget data service first
        let budgetDataService = BudgetDataService(
            adjustment: goals?.adjustment,
            date: date
        )

        // Load budget data first
        await budgetDataService.refresh()

        // Only create macros data service if budget data loaded successfully
        var macrosService: MacrosAnalyticsService? = nil

        if let budgetService = budgetDataService.budgetService {
            let macrosDataService = MacrosDataService(
                budgetService: budgetService,
                adjustments: goals?.macros,
                date: date
            )

            // Load macros data with budget dependency
            await macrosDataService.refresh()
            macrosService = macrosDataService.macrosService
        }

        return MacrosEntry(
            date: date,
            macrosService: macrosService,
            configuration: configuration
        )
    }
}

struct MacrosEntry: TimelineEntry, Sendable {
    let date: Date
    let macrosService: MacrosAnalyticsService?
    let configuration: MacroSelectionAppIntent
}
