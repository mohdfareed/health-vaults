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
            .refreshOnHealthDataChange(for: [.dietaryCalories, .bodyMass, .bodyFatPercentage, .protein, .carbs, .fat]) {
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
                    subtitle: "kcal/day",
                    description: "Maintenance + goal adjustment"
                )
            } header: {
                Text("Budget Input")
            }

            Section {
                calorieValue(
                    budgetDataService.budgetService?.calories.currentIntake,
                    title: "Today's Intake",
                    icon: Image.calories,
                    subtitle: "kcal/day"
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
                percentageValue(
                    budgetDataService.budgetService?.weight.bodyFatPercentageUsed.map { $0 * 100 },
                    title: "Body Fat Used",
                    icon: Image.bodyFat,
                    tint: .bodyFat
                )
            } header: {
                Text("Data Used")
            }

            Section {
                calorieValue(
                    budgetDataService.budgetService.map { $0.credit },
                    title: "Credit",
                    icon: Image.calories,
                    subtitle: "kcal/day",
                    description: "Weekly over/under balance"
                )
                daysValue(
                    budgetDataService.budgetService.map { Double($0.daysLeft) },
                    title: "Until Week Reset"
                )
                calorieValue(
                    budgetDataService.budgetService?.dailyAdjustment,
                    title: "Credit Adjustment",
                    icon: Image.calories,
                    subtitle: "kcal/day",
                    description: "Credit ÷ days left (±500 cap)"
                )
                calorieValue(
                    budgetDataService.budgetService?.budget,
                    title: "Today's Budget",
                    icon: Image.calories,
                    subtitle: "kcal/day",
                    description: "Base budget + credit adjustment"
                )
                calorieValue(
                    budgetDataService.budgetService?.calories.currentIntake,
                    title: "Today's Intake",
                    icon: Image.calories,
                    subtitle: "kcal/day"
                )
                calorieValue(
                    budgetDataService.budgetService?.remaining,
                    title: "Remaining",
                    icon: Image.calories,
                    subtitle: "kcal/day",
                    description: "Budget − intake"
                )
            } header: {
                Text("Budget Calculation")
            }

            Section("Diagnostics") {
                NavigationLink {
                    diagnosticsPage(title: "Data Coverage") {
                        dataPointValue(
                            budgetDataService.budgetService?.weight.dataPointCount,
                            title: "Weight Data Points"
                        )
                        dataPointValue(
                            budgetDataService.budgetService?.calories.dataPointCount,
                            title: "Calorie Data Points"
                        )
                        dataPointValue(
                            budgetDataService.budgetService?.weight.bodyFatDataPointCount,
                            title: "Body Fat Data Points"
                        )
                        dateRangeValue(
                            budgetDataService.budgetService?.weight.weightDateRange,
                            title: "Weight Data Range"
                        )
                        dateRangeValue(
                            budgetDataService.budgetService?.calories.intakeDateRange,
                            title: "Calorie Data Range"
                        )
                        dateRangeValue(
                            budgetDataService.budgetService?.weight.bodyFatDateRange,
                            title: "Body Fat Data Range"
                        )
                    }
                } label: {
                    Label("Data Coverage", systemImage: "chart.bar.doc.horizontal")
                }
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
            }
        }
    }

    @ViewBuilder
    private var algorithmStatusRow: some View {
        LabeledContent {
            HStack(spacing: 6) {
                if budgetDataService.budgetService?.weight.isValid != true {
                    Text("Calibrating")
                        .foregroundStyle(.secondary)
                }
                Circle()
                    .fill(budgetDataService.budgetService?.weight.isValid == true ? .green : .yellow)
                    .frame(width: 8, height: 8)
            }
        } label: {
            Label("Maintenance Status", systemImage: "waveform.path.ecg")
        }
    }

    @ViewBuilder
    private func diagnosticsPage<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            List {
                content()
            }
            .navigationTitle(title)
            .refreshable {
                await refresh()
            }
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
            subtitle: "g/day"
        )
        macroValue(
            remaining,
            title: remainingTitle,
            icon: icon,
            tint: tint,
            subtitle: "g/day"
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
            .refreshOnHealthDataChange(for: [.dietaryCalories, .bodyMass, .bodyFatPercentage, .protein, .carbs, .fat]) {
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
        subtitle: String? = nil,
        description: String? = nil
    ) -> some View {
        MeasurementField(
            validator: nil, format: CalorieFieldDefinition().formatter,
            showPicker: true,
            measurement: .init(
                baseValue: .constant(value),
                definition: UnitDefinition<UnitEnergy>.calorie
            )
        ) {
            OverviewDetailLabel(
                title: String(localized: title),
                icon: icon,
                tint: .calories,
                unitText: subtitle,
                description: description
            )
        }
        .disabled(true)
    }

    /// Days value display (for week reset countdown).
    private func daysValue(
        _ value: Double?,
        title: String.LocalizationValue,
        description: String? = nil
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
            OverviewDetailLabel(
                title: String(localized: title),
                icon: Image(systemName: "calendar"),
                tint: .secondary,
                unitText: "days",
                description: description
            )
        }
    }

    /// Weight rate value (kg/week or lb/week) with localized unit display.
    private func weightRateValue(
        _ value: Double?,
        title: String.LocalizationValue,
        icon: Image? = nil,
        description: String? = nil
    ) -> some View {
        WeightRateRow(value: value, title: title, icon: icon, description: description)
    }

    /// Confidence percentage display.
    private func confidenceValue(
        _ value: Double?,
        title: String.LocalizationValue,
        description: String? = nil
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
            OverviewDetailLabel(
                title: String(localized: title),
                icon: Image(systemName: "percent"),
                tint: .secondary,
                unitText: nil,
                description: description
            )
        }
        .disabled(true)
    }

    private func macroValue(
        _ value: Double?,
        title: String.LocalizationValue,
        icon: Image? = nil, tint: Color? = nil,
        subtitle: String? = nil,
        description: String? = nil
    ) -> some View {
        MeasurementField(
            validator: nil, format: ProteinFieldDefinition().formatter,
            showPicker: true,
            measurement: .init(
                baseValue: .constant(value),
                definition: UnitDefinition<UnitMass>.macro
            ),
        ) {
            OverviewDetailLabel(
                title: String(localized: title),
                icon: icon,
                tint: tint,
                unitText: subtitle,
                description: description
            )
        }
        .disabled(true)
    }

    private func percentageValue(
        _ value: Double?,
        title: String.LocalizationValue,
        icon: Image? = nil,
        tint: Color? = nil,
        description: String? = nil
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
            OverviewDetailLabel(
                title: String(localized: title),
                icon: icon,
                tint: tint,
                unitText: "%",
                description: description
            )
        }
        .disabled(true)
    }

    private func dataPointValue(
        _ value: Int?,
        title: String.LocalizationValue,
        description: String? = nil
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
            OverviewDetailLabel(
                title: String(localized: title),
                icon: Image(systemName: "number"),
                tint: .secondary,
                unitText: nil,
                description: description
            )
        }
        .disabled(true)
    }

    private func dateRangeValue(
        _ range: (from: Date, to: Date)?,
        title: String.LocalizationValue,
        description: String? = nil
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
            OverviewDetailLabel(
                title: String(localized: title),
                icon: Image(systemName: "calendar"),
                tint: .secondary,
                unitText: nil,
                description: description
            )
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
    let description: String?

    init(value: Double?, title: String.LocalizationValue, icon: Image?, description: String?) {
        self._measurement = LocalizedMeasurement(
            .constant(value),
            definition: UnitDefinition<UnitMass>.weight
        )
        self.title = title
        self.icon = icon
        self.description = description
    }

    var body: some View {
        MeasurementField(
            validator: nil, format: WeightFieldDefinition().formatter,
            showPicker: true,
            measurement: $measurement
        ) {
            OverviewDetailLabel(
                title: String(localized: title),
                icon: icon,
                tint: .weight,
                unitText: "\(measurement.unit.symbol)/wk",
                description: description
            )
        }
        .disabled(true)
    }
}

private struct OverviewDetailLabel: View {
    let title: String
    let icon: Image?
    let tint: Color?
    let unitText: String?
    let description: String?

    var body: some View {
        DetailedRow(image: icon, tint: tint) {
            Text(title)
        } subtitle: {
            if let unitText {
                Text(unitText).textScale(.secondary)
            }
        } details: {
            if let description {
                Text(description)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
