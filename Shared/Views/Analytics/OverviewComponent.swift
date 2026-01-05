import Charts
import SwiftData
import SwiftUI

// MARK: - Overview Component
// ============================================================================

/// Reusable overview component for dashboard detailed analytics
public struct OverviewComponent: View {
    @State private var budgetDataService: BudgetDataService
    @State private var macrosDataService: MacrosDataService

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
                await refresh()
            }
            .refreshOnHealthDataChange(for: [.dietaryCalories, .bodyMass, .protein, .carbs, .fat]) {
                await refresh()
            }

            .animation(.default, value: macrosDataService.macrosService != nil)
            .animation(.default, value: macrosDataService.isLoading)
            .animation(.default, value: budgetDataService.isLoading)
        }
    }

    @ViewBuilder var overviewSections: some View {
        Section("Calories") {
            calorieValue(
                budgetDataService.budgetService?.calories.currentIntake,
                title: "Intake",
                icon: Image.calories
            )
            calorieValue(
                budgetDataService.budgetService?.calories.smoothedIntake,
                title: "EWMA",
                icon: Image.calories
            )
        }

        Section {
            weightValue(
                budgetDataService.budgetService?.weight.weightSlope,
                title: "Change",
                icon: Image.weight
            )
            calorieValue(
                budgetDataService.budgetService?.weight.calories.smoothedIntake,
                title: "Historical Intake",
                icon: Image.calories
            )
            calorieValue(
                budgetDataService.budgetService?.weight.maintenance,
                title: "Maintenance",
                icon: Image.calories
            )
        } header: {
            Text("Maintenance")
        } footer: {
            if budgetDataService.budgetService?.weight.isValid != true {
                VStack(alignment: .leading) {
                    HStack(alignment: .firstTextBaseline) {
                        Image.maintenance.foregroundStyle(Color.calories)
                            .symbolEffect(
                                .rotate.byLayer,
                                options: .repeat(.continuous)
                            )
                        Text("Maintenance calibration in progress...")
                    }
                    Text("At least 14 days of weight and calorie data is required.")
                }
            }
        }

        Section("Budget") {
            calorieValue(
                budgetDataService.budgetService?.remaining,
                title: "Remaining",
                icon: Image.calories
            )

            calorieValue(
                budgetDataService.budgetService?.baseBudget,
                title: "Base",
                icon: Image.calories
            )

            calorieValue(
                budgetDataService.budgetService?.budget,
                title: "Adjusted",
                icon: Image.calories
            )

            calorieValue(
                budgetDataService.budgetService?.credit,
                title: "Credit",
                icon: Image.calories
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
            .task {
                await refresh()
            }
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
                icon: Image.protein, tint: .protein
            )

            macroValue(
                macrosDataService.macrosService?.protein.smoothedIntake,
                title: "EWMA",
                icon: Image.protein, tint: .protein
            )
        }

        Section("Budget") {
            macroValue(
                macrosDataService.macrosService?.remaining?.protein,
                title: "Remaining",
                icon: Image.protein, tint: .protein
            )

            macroValue(
                macrosDataService.macrosService?.baseBudgets?.protein,
                title: "Base",
                icon: Image.protein, tint: .protein
            )

            macroValue(
                macrosDataService.macrosService?.budgets?.protein,
                title: "Adjusted",
                icon: Image.protein, tint: .protein
            )

            macroValue(
                macrosDataService.macrosService?.credits?.protein,
                title: "Credit",
                icon: Image.protein, tint: .protein
            )
        }
    }

    @ViewBuilder var carbsSection: some View {
        Section("Carbs") {
            macroValue(
                macrosDataService.macrosService?.carbs.currentIntake,
                title: "Intake",
                icon: Image.carbs, tint: .carbs
            )

            macroValue(
                macrosDataService.macrosService?.carbs.smoothedIntake,
                title: "EWMA",
                icon: Image.carbs, tint: .carbs
            )
        }

        Section("Budget") {
            macroValue(
                macrosDataService.macrosService?.remaining?.carbs,
                title: "Remaining",
                icon: Image.carbs, tint: .carbs
            )

            macroValue(
                macrosDataService.macrosService?.baseBudgets?.carbs,
                title: "Base",
                icon: Image.carbs, tint: .carbs
            )

            macroValue(
                macrosDataService.macrosService?.budgets?.carbs,
                title: "Adjusted",
                icon: Image.carbs, tint: .carbs
            )

            macroValue(
                macrosDataService.macrosService?.credits?.carbs,
                title: "Credit",
                icon: Image.carbs, tint: .carbs
            )
        }
    }

    @ViewBuilder var fatSection: some View {
        Section("Fat") {
            macroValue(
                macrosDataService.macrosService?.fat.currentIntake,
                title: "Intake",
                icon: Image.fat, tint: .fat
            )

            macroValue(
                macrosDataService.macrosService?.fat.smoothedIntake,
                title: "EWMA",
                icon: Image.fat, tint: .fat
            )
        }

        Section("Budget") {
            macroValue(
                macrosDataService.macrosService?.remaining?.fat,
                title: "Remaining",
                icon: Image.fat, tint: .fat
            )

            macroValue(
                macrosDataService.macrosService?.baseBudgets?.fat,
                title: "Base",
                icon: Image.fat, tint: .fat
            )

            macroValue(
                macrosDataService.macrosService?.budgets?.fat,
                title: "Adjusted",
                icon: Image.fat, tint: .fat
            )

            macroValue(
                macrosDataService.macrosService?.credits?.fat,
                title: "Credit",
                icon: Image.fat, tint: .fat
            )
        }
    }

    private func calorieValue(
        _ value: Double?,
        title: String.LocalizationValue,
        icon: Image? = nil
    ) -> some View {
        MeasurementField(
            validator: nil, format: CalorieFieldDefinition().formatter,
            showPicker: true,
            measurement: .init(
                baseValue: .constant(value),
                definition: UnitDefinition<UnitEnergy>.calorie
            ),
        ) {
            DetailedRow(image: icon, tint: .calories) {
                Text(String(localized: title))
            } subtitle: {
            } details: {
            }
        }
        .disabled(true)
    }

    private func macroValue(
        _ value: Double?,
        title: String.LocalizationValue,
        icon: Image? = nil, tint: Color? = nil
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
            } details: {
            }
        }
        .disabled(true)
    }

    @ViewBuilder private func weightValue(
        _ value: Double?,
        title: String.LocalizationValue,
        icon: Image? = nil
    ) -> some View {
        MeasurementField(
            validator: nil, format: WeightFieldDefinition().formatter,
            showPicker: true,
            measurement: .init(
                baseValue: .constant(value),
                definition: UnitDefinition<UnitMass>.weight
            ),
        ) {
            DetailedRow(image: icon, tint: .weight) {
                Text(String(localized: title))
            } subtitle: {
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
