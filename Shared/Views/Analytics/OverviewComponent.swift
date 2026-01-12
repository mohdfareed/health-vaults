import Charts
import SwiftData
import SwiftUI

// MARK: - Overview Component
// ============================================================================

/// Reusable overview component for dashboard detailed analytics
public struct OverviewComponent: View {
    @State private var budgetDataService: BudgetDataService
    @State private var macrosDataService: MacrosDataService
    @State private var hasLoaded: Bool = false

    // Store initial parameters for rebuilding services
    private let adjustment: Double?
    private let macroAdjustments: CalorieMacros?
    private let date: Date

    private let logger = AppLogger.new(for: OverviewComponent.self)

    public init(
        adjustment: Double? = nil,
        macroAdjustments: CalorieMacros? = nil,
        date: Date = Date()
    ) {
        // Store parameters
        self.adjustment = adjustment
        self.macroAdjustments = macroAdjustments
        self.date = date

        self._budgetDataService = State(
            initialValue: BudgetDataService(
                adjustment: adjustment,
                date: date
            ))

        // Note: MacrosDataService will be created properly in refresh() with budget dependency
        self._macrosDataService = State(
            initialValue: MacrosDataService(
                adjustments: macroAdjustments,
                date: date
            ))
    }

    // Keep body exactly the same as OverviewWidget
    public var body: some View {
        Section("Data") {
            NavigationLink(
                destination: overviewPage
            ) {
                LabeledContent {
                    HStack {
                        if budgetDataService.budgetService?.isValid != true {
                            Image.maintenance.foregroundStyle(Color.calories)
                                .symbolEffect(
                                    .rotate.byLayer,
                                    options: .repeat(.continuous)
                                )
                        }
                    }
                } label: {
                    Label {
                        HStack {
                            Text("Overview")
                            if budgetDataService.budgetService?.weight.isValid != true {
                                Text("Calibrating...")
                                    .textScale(.secondary)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "chart.line.text.clipboard.fill")
                    }
                }
            }
        }
        .animation(.default, value: budgetDataService.budgetService?.isValid)
        .animation(.default, value: budgetDataService.budgetService?.weight.isValid)
    }

    @ViewBuilder var overviewPage: some View {
        NavigationStack {
            List {
                if macrosDataService.macrosService != nil {
                    overviewSections
                    macrosPage
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
            }
            .navigationTitle("Overview")
            .refreshable {
                await refresh()
            }
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                await refresh()
            }
            .refreshOnHealthDataChange(for: [.dietaryCalories, .bodyMass, .protein, .carbs, .fat]) {
                await refresh()
            }
            .onChange(of: adjustment) { _, newAdjustment in
                budgetDataService = BudgetDataService(adjustment: newAdjustment, date: date)
                Task { await refresh() }
            }
            .onChange(of: macroAdjustments) { _, newMacroAdjustments in
                macrosDataService = MacrosDataService(
                    budgetService: budgetDataService.budgetService,
                    adjustments: newMacroAdjustments,
                    date: date
                )
                Task { await macrosDataService.refresh() }
            }
            .animation(.default, value: macrosDataService.macrosService != nil)
            .animation(.default, value: macrosDataService.isLoading)
            .animation(.default, value: budgetDataService.isLoading)
        }
    }

    @ViewBuilder var overviewSections: some View {
        Section("Intake") {
            calorieValue(
                budgetDataService.budgetService?.calories.currentIntake,
                title: "Today",
                icon: Image.calories,
                subtitle: "kcal"
            )
            calorieValue(
                budgetDataService.budgetService?.calories.smoothedIntake,
                title: "Recent Average",
                icon: Image.calories,
                subtitle: "kcal/day"
            )
            calorieValue(
                budgetDataService.budgetService?.calories.longTermSmoothedIntake,
                title: "Sustained Average",
                icon: Image.calories,
                subtitle: "kcal/day"
            )
        }

        Section {
            weightRateValue(
                budgetDataService.budgetService?.weight.weightSlope,
                title: "Weight Trend",
                icon: Image.weight
            )
            confidenceValue(
                budgetDataService.budgetService?.weight.confidence,
                title: "Data Confidence"
            )
            calorieValue(
                budgetDataService.budgetService?.weight.maintenance,
                title: "Maintenance",
                icon: Image.calories,
                subtitle: "kcal/day"
            )
        } header: {
            Text("Maintenance")
        } footer: {
            if budgetDataService.budgetService?.weight.isValid != true {
                VStack(alignment: .leading) {
                    Text(
                        "Log weight and calories for 2+ weeks to calculate your maintenance. Until then, using 2000 kcal baseline."
                    )
                    HStack(alignment: .firstTextBaseline) {
                        Image.maintenance.foregroundStyle(Color.calories)
                            .symbolEffect(
                                .rotate.byLayer,
                                options: .repeat(.continuous)
                            )
                        Text("Calibrating...")
                    }
                }
            } else {
                Text(
                    "Your maintenance is the calories you burn per day. Calculated from your weight trend and intake."
                )
            }
        }

        Section {
            calorieValue(
                budgetDataService.budgetService?.baseBudget,
                title: "Base Budget",
                icon: Image.calories,
                subtitle: "kcal/day"
            )
            calorieValue(
                budgetDataService.budgetService.map { $0.credit },
                title: "Credit",
                icon: Image.calories,
                subtitle: "kcal"
            )
            daysValue(
                budgetDataService.budgetService.map { Double($0.daysLeft) },
                title: "Until Week Reset"
            )
            calorieValue(
                budgetDataService.budgetService?.dailyAdjustment,
                title: "Credit Adjustment",
                icon: Image.calories,
                subtitle: "kcal/day"
            )
            calorieValue(
                budgetDataService.budgetService?.budget,
                title: "Budget",
                icon: Image.calories,
                subtitle: "kcal"
            )
        } header: {
            Text("Budget")
        } footer: {
            Text(
                "Credit is your over/under from the past 7 days, spread across days until your week resets. Capped at ±500 kcal/day."
            )
        }
    }

    @ViewBuilder var macrosPage: some View {
        Section {
            NavigationLink(
                destination: macroDetailPage(title: "Protein", content: proteinSection)
            ) {
                DetailedRow(image: Image.protein, tint: .protein) {
                    Text("Protein")
                } subtitle: {
                } details: {
                }
            }

            NavigationLink(
                destination: macroDetailPage(title: "Carbohydrates", content: carbsSection)
            ) {
                DetailedRow(image: Image.carbs, tint: .carbs) {
                    Text("Carbs")
                } subtitle: {
                } details: {
                }
            }

            NavigationLink(
                destination: macroDetailPage(title: "Fat", content: fatSection)
            ) {
                DetailedRow(image: Image.fat, tint: .fat) {
                    Text("Fat")
                } subtitle: {
                } details: {
                }
            }
        } header: {
            Text("Macros")
        } footer: {
            Text(
                "Macros are calculated based on the calorie budget."
            )
        }
    }

    @ViewBuilder
    private func macroDetailPage<Content: View>(title: String, content: Content) -> some View {
        NavigationStack {
            List {
                content
            }
            .navigationTitle(title)
            .refreshable {
                await refresh()
            }
            // No .task here - data is already loaded from parent overviewPage
            .refreshOnHealthDataChange(for: [.dietaryCalories, .bodyMass, .protein, .carbs, .fat]) {
                await refresh()
            }

            .animation(.default, value: macrosDataService.macrosService != nil)
            .animation(.default, value: macrosDataService.isLoading)
            .animation(.default, value: budgetDataService.isLoading)
        }
    }

    @ViewBuilder var proteinSection: some View {
        Section("Protein") {
            macroValue(
                macrosDataService.macrosService?.protein.currentIntake,
                title: "Intake",
                icon: Image.protein, tint: .protein,
                subtitle: "today"
            )

            macroValue(
                macrosDataService.macrosService?.protein.smoothedIntake,
                title: "EWMA",
                icon: Image.protein, tint: .protein,
                subtitle: "/day"
            )
        }

        Section("Budget") {
            macroValue(
                macrosDataService.macrosService?.remaining?.protein,
                title: "Remaining",
                icon: Image.protein, tint: .protein,
                subtitle: "today"
            )

            macroValue(
                macrosDataService.macrosService?.budgets?.protein,
                title: "Budget",
                icon: Image.protein, tint: .protein,
                subtitle: "/day"
            )
        }
    }

    @ViewBuilder var carbsSection: some View {
        Section("Carbs") {
            macroValue(
                macrosDataService.macrosService?.carbs.currentIntake,
                title: "Intake",
                icon: Image.carbs, tint: .carbs,
                subtitle: "today"
            )

            macroValue(
                macrosDataService.macrosService?.carbs.smoothedIntake,
                title: "EWMA",
                icon: Image.carbs, tint: .carbs,
                subtitle: "/day"
            )
        }

        Section("Budget") {
            macroValue(
                macrosDataService.macrosService?.remaining?.carbs,
                title: "Remaining",
                icon: Image.carbs, tint: .carbs,
                subtitle: "today"
            )

            macroValue(
                macrosDataService.macrosService?.budgets?.carbs,
                title: "Budget",
                icon: Image.carbs, tint: .carbs,
                subtitle: "/day"
            )
        }
    }

    @ViewBuilder var fatSection: some View {
        Section("Fat") {
            macroValue(
                macrosDataService.macrosService?.fat.currentIntake,
                title: "Intake",
                icon: Image.fat, tint: .fat,
                subtitle: "today"
            )

            macroValue(
                macrosDataService.macrosService?.fat.smoothedIntake,
                title: "EWMA",
                icon: Image.fat, tint: .fat,
                subtitle: "/day"
            )
        }

        Section("Budget") {
            macroValue(
                macrosDataService.macrosService?.remaining?.fat,
                title: "Remaining",
                icon: Image.fat, tint: .fat,
                subtitle: "today"
            )

            macroValue(
                macrosDataService.macrosService?.budgets?.fat,
                title: "Budget",
                icon: Image.fat, tint: .fat,
                subtitle: "/day"
            )
        }
    }

    private func calorieValue(
        _ value: Double?,
        title: String.LocalizationValue,
        icon: Image? = nil,
        subtitle: String? = nil
    ) -> some View {
        MeasurementField(
            validator: nil, format: CalorieFieldDefinition().formatter,
            showPicker: true,
            measurement: .init(
                baseValue: .constant(value),
                definition: UnitDefinition<UnitEnergy>.calorie
            )
        ) {
            DetailedRow(image: icon, tint: .calories) {
                Text(String(localized: title))
            } subtitle: {
                if let subtitle { Text(subtitle).textScale(.secondary) }
            } details: {
            }
        }
        .disabled(true)
    }

    /// Days value display (for week reset countdown).
    private func daysValue(
        _ value: Double?,
        title: String.LocalizationValue
    ) -> some View {
        LabeledContent {
            if let value = value {
                Text("\(Int(value))")
                    .foregroundStyle(.tertiary)
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
            }
        } label: {
            DetailedRow(image: Image(systemName: "calendar"), tint: .secondary) {
                Text(String(localized: title))
            } subtitle: {
                Text("days").textScale(.secondary)
            } details: {
            }
        }
    }

    /// Weight rate value (kg/week or lb/week) with localized unit display.
    private func weightRateValue(
        _ value: Double?,
        title: String.LocalizationValue,
        icon: Image? = nil
    ) -> some View {
        WeightRateRow(value: value, title: title, icon: icon)
    }

    /// Confidence percentage display.
    private func confidenceValue(
        _ value: Double?,
        title: String.LocalizationValue
    ) -> some View {
        LabeledContent {
            if let value = value {
                Text("\(Int(value * 100))%")
                    .foregroundStyle(.tertiary)
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
            }
        } label: {
            Label {
                Text(String(localized: title))
            } icon: {
                Image(systemName: "percent")
                    .foregroundStyle(.tertiary)
            }
        }
        .disabled(true)
    }

    private func macroValue(
        _ value: Double?,
        title: String.LocalizationValue,
        icon: Image? = nil, tint: Color? = nil,
        subtitle: String? = nil
    ) -> some View {
        MeasurementField(
            validator: nil, format: ProteinFieldDefinition().formatter,
            showPicker: true,
            measurement: .init(
                baseValue: .constant(value),
                definition: UnitDefinition<UnitMass>.macro
            ),
        ) {
            DetailedRow(image: icon, tint: tint) {
                Text(String(localized: title))
            } subtitle: {
                if let subtitle { Text(subtitle).textScale(.secondary) }
            } details: {
            }
        }
        .disabled(true)
    }

    func refresh() async {
        // First refresh budget data
        await budgetDataService.refresh()

        // Create new macros data service with budget dependency if budget loaded successfully
        if let budgetService = budgetDataService.budgetService {
            await MainActor.run {
                macrosDataService = MacrosDataService(
                    budgetService: budgetService,
                    adjustments: macroAdjustments,
                    date: date
                )
            }
            await macrosDataService.refresh()
        } else {
            // Fallback: try to refresh macros without budget dependency
            await macrosDataService.refresh()
        }
    }
}

// MARK: - Weight Rate Row
// ============================================================================

/// A row displaying a weight rate value with localized unit (e.g., kg/wk or lb/wk)
private struct WeightRateRow: View {
    @LocalizedMeasurement var measurement: Measurement<UnitMass>

    let title: String.LocalizationValue
    let icon: Image?

    init(value: Double?, title: String.LocalizationValue, icon: Image?) {
        self._measurement = LocalizedMeasurement(
            .constant(value),
            definition: UnitDefinition<UnitMass>.weight
        )
        self.title = title
        self.icon = icon
    }

    var body: some View {
        MeasurementField(
            validator: nil, format: WeightFieldDefinition().formatter,
            showPicker: true,
            measurement: $measurement
        ) {
            DetailedRow(image: icon, tint: .weight) {
                Text(String(localized: title))
            } subtitle: {
                Text("\(measurement.unit.symbol)/wk").textScale(.secondary)
            } details: {
            }
        }
        .disabled(true)
    }
}
