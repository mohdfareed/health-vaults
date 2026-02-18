import Charts
import SwiftData
import SwiftUI

// MARK: - Overview Component
// ============================================================================

/// Reusable overview component for dashboard detailed analytics
public struct OverviewComponent: View {
    public enum Focus {
        case calories
        case macros
    }

    @State private var budgetDataService: BudgetDataService
    @State private var macrosDataService: MacrosDataService
    @State private var hasLoaded: Bool = false

    // Store initial parameters for rebuilding services
    private let adjustment: Double?
    private let macroAdjustments: CalorieMacros?
    private let date: Date
    private let focus: Focus

    private let logger = AppLogger.new(for: OverviewComponent.self)

    public init(
        adjustment: Double? = nil,
        macroAdjustments: CalorieMacros? = nil,
        date: Date = Date(),
        focus: Focus = .calories
    ) {
        // Store parameters
        self.adjustment = adjustment
        self.macroAdjustments = macroAdjustments
        self.date = date
        self.focus = focus

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

    public var body: some View {
        overviewPage
    }

    @ViewBuilder var overviewPage: some View {
        NavigationStack {
            List {
                if macrosDataService.macrosService != nil {
                    diagnosticSections
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

    @ViewBuilder var diagnosticSections: some View {
        if focus == .calories {
            Section {
                algorithmStatusRow
                confidenceValue(
                    budgetDataService.budgetService?.weight.confidence,
                    title: "Weight Data Confidence"
                )
                confidenceValue(
                    budgetDataService.budgetService?.calories.confidence,
                    title: "Calorie Data Confidence"
                )
                daysValue(
                    budgetDataService.budgetService.map { Double($0.daysLeft) },
                    title: "Days Remaining This Week"
                )
            } header: {
                Text("Snapshot")
            } footer: {
                Text("Model readiness and data quality indicators.")
            }

            Section {
                calorieValue(
                    budgetDataService.budgetService?.weight.maintenance,
                    title: "Maintenance",
                    icon: Image.calories,
                    subtitle: "kcal/day"
                )
                calorieValue(
                    adjustment,
                    title: "Goal Adjustment",
                    icon: Image(systemName: "plusminus.circle"),
                    subtitle: "kcal/day"
                )
                calorieValue(
                    budgetDataService.budgetService?.baseBudget,
                    title: "Base Budget",
                    icon: Image.calories,
                    subtitle: "kcal/day"
                )
            } header: {
                Text("Budget Input")
            } footer: {
                Text("Base budget is the core input for daily budget calculations.")
            }

            Section {
                calorieValue(
                    budgetDataService.budgetService?.calories.currentIntake,
                    title: "Today’s Intake",
                    icon: Image.calories,
                    subtitle: "kcal"
                )
                calorieValue(
                    budgetDataService.budgetService?.calories.smoothedIntake,
                    title: "7-Day Average",
                    icon: Image.calories,
                    subtitle: "kcal/day"
                )
                calorieValue(
                    budgetDataService.budgetService?.calories.longTermSmoothedIntake,
                    title: "Long-Term Average",
                    icon: Image.calories,
                    subtitle: "kcal/day"
                )
                weightRateValue(
                    budgetDataService.budgetService?.weight.weightSlope,
                    title: "Weight Trend",
                    icon: Image.weight
                )
            } header: {
                Text("Data Used")
            } footer: {
                Text(
                    "These are the recent and smoothed data streams used by the maintenance model."
                )
            }

            Section {
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
                    title: "Today’s Budget",
                    icon: Image.calories,
                    subtitle: "kcal/day"
                )
                calorieValue(
                    budgetDataService.budgetService?.calories.currentIntake,
                    title: "Today’s Intake",
                    icon: Image.calories,
                    subtitle: "kcal/day"
                )
                calorieValue(
                    budgetDataService.budgetService?.remaining,
                    title: "Remaining",
                    icon: Image.calories,
                    subtitle: "kcal/day"
                )
            } header: {
                Text("Budget Math")
            } footer: {
                Text(
                    "Base budget = maintenance + goal adjustment. Today’s budget = base budget + (credit ÷ days remaining). Daily credit adjustment is capped at ±500 kcal/day."
                )
            }

            Section {
                dataPointValue(
                    budgetDataService.budgetService?.weight.dataPointCount,
                    title: "Weight Data Points"
                )
                dataPointValue(
                    budgetDataService.budgetService?.calories.dataPointCount,
                    title: "Calorie Data Points"
                )
                dateRangeValue(
                    budgetDataService.budgetService?.weight.weightDateRange,
                    title: "Weight Data Range"
                )
                dateRangeValue(
                    budgetDataService.budgetService?.calories.intakeDateRange,
                    title: "Calorie Data Range"
                )
            } header: {
                Text("Data Coverage")
            } footer: {
                Text("Use this to verify what data range and volume are driving the model.")
            }
        }

        if focus == .macros {
            Section {
                calorieValue(
                    macrosDataService.macrosService?.calories?.baseBudget,
                    title: "Base Budget",
                    icon: Image.calories,
                    subtitle: "kcal/day"
                )
            } header: {
                Text("Budget Input")
            } footer: {
                Text("This base budget is used for all macro budget calculations.")
            }

            Section("Protein") {
                macroSummaryRows(
                    percentageTitle: "Target",
                    percentage: macrosDataService.macrosService?.adjustments?.protein,
                    budgetTitle: "Budget",
                    intakeTitle: "Intake",
                    remainingTitle: "Remaining",
                    icon: Image.protein,
                    tint: .protein,
                    intake: macrosDataService.macrosService?.protein.currentIntake,
                    budget: macrosDataService.macrosService?.budgets?.protein,
                    remaining: macrosDataService.macrosService?.remaining?.protein
                )
            }

            Section("Carbohydrates") {
                macroSummaryRows(
                    percentageTitle: "Target",
                    percentage: macrosDataService.macrosService?.adjustments?.carbs,
                    budgetTitle: "Budget",
                    intakeTitle: "Intake",
                    remainingTitle: "Remaining",
                    icon: Image.carbs,
                    tint: .carbs,
                    intake: macrosDataService.macrosService?.carbs.currentIntake,
                    budget: macrosDataService.macrosService?.budgets?.carbs,
                    remaining: macrosDataService.macrosService?.remaining?.carbs
                )
            }

            Section {
                macroSummaryRows(
                    percentageTitle: "Target",
                    percentage: macrosDataService.macrosService?.adjustments?.fat,
                    budgetTitle: "Budget",
                    intakeTitle: "Intake",
                    remainingTitle: "Remaining",
                    icon: Image.fat,
                    tint: .fat,
                    intake: macrosDataService.macrosService?.fat.currentIntake,
                    budget: macrosDataService.macrosService?.budgets?.fat,
                    remaining: macrosDataService.macrosService?.remaining?.fat
                )
            } header: {
                Text("Fat")
            } footer: {
                Text(
                    "Macro budgets are derived from your calorie budget and macro targets."
                )
            }
        }
    }

    @ViewBuilder
    private var algorithmStatusRow: some View {
        LabeledContent {
            HStack(spacing: 6) {
                Circle()
                    .fill(budgetDataService.budgetService?.weight.isValid == true ? .green : .yellow)
                    .frame(width: 8, height: 8)
                Text(
                    budgetDataService.budgetService?.weight.isValid == true
                        ? "Ready"
                        : "Calibrating."
                )
                .foregroundStyle(.secondary)
            }
        } label: {
            Label("Maintenance Status", systemImage: "waveform.path.ecg")
        }
    }

    @ViewBuilder
    private func macroSummaryRows(
        percentageTitle: String.LocalizationValue,
        percentage: Double?,
        budgetTitle: String.LocalizationValue,
        intakeTitle: String.LocalizationValue,
        remainingTitle: String.LocalizationValue,
        icon: Image,
        tint: Color,
        intake: Double?,
        budget: Double?,
        remaining: Double?
    ) -> some View {
        percentageValue(
            percentage,
            title: percentageTitle,
            icon: icon,
            tint: tint
        )
        macroValue(
            budget,
            title: budgetTitle,
            icon: icon,
            tint: tint,
            subtitle: "g/day"
        )
        macroValue(
            intake,
            title: intakeTitle,
            icon: icon,
            tint: tint,
            subtitle: "g"
        )
        macroValue(
            remaining,
            title: remainingTitle,
            icon: icon,
            tint: tint,
            subtitle: "g"
        )
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

    private func percentageValue(
        _ value: Double?,
        title: String.LocalizationValue,
        icon: Image? = nil,
        tint: Color? = nil
    ) -> some View {
        MeasurementField(
            validator: nil,
            format: ProteinPercentDefinition().formatter,
            showPicker: false,
            measurement: .init(
                baseValue: .constant(value),
                definition: UnitDefinition.percentage
            )
        ) {
            DetailedRow(image: icon, tint: tint) {
                Text(String(localized: title))
            } subtitle: {
                Text("%").textScale(.secondary)
            } details: {
            }
        }
        .disabled(true)
    }

    private func dataPointValue(
        _ value: Int?,
        title: String.LocalizationValue
    ) -> some View {
        LabeledContent {
            if let value {
                Text("\(value)")
                    .foregroundStyle(.tertiary)
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
            }
        } label: {
            Label {
                Text(String(localized: title))
            } icon: {
                Image(systemName: "number")
                    .foregroundStyle(.tertiary)
            }
        }
        .disabled(true)
    }

    private func dateRangeValue(
        _ range: (from: Date, to: Date)?,
        title: String.LocalizationValue
    ) -> some View {
        LabeledContent {
            if let range {
                Text("\(range.from.formatted(date: .abbreviated, time: .omitted)) – \(range.to.formatted(date: .abbreviated, time: .omitted))")
                    .foregroundStyle(.tertiary)
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
            }
        } label: {
            Label {
                Text(String(localized: title))
            } icon: {
                Image(systemName: "calendar")
                    .foregroundStyle(.tertiary)
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
