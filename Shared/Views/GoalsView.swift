import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Combined Goals View
// ============================================================================

public struct GoalsView: View {
    private enum GoalsSection: String, CaseIterable, Identifiable {
        case calories = "Calories"
        case macros = "Macros"

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context: ModelContext
    @Query.Singleton var goals: UserGoals
    @State private var selectedSection: GoalsSection = .calories

    public init(_ id: UUID) {
        self._goals = .init(id)
    }

    public var body: some View {
        Form {
            Section {
                Picker("Goals Section", selection: $selectedSection) {
                    ForEach(GoalsSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            switch selectedSection {
            case .calories:
                CalorieGoalFields(goals: Bindable(goals))
            case .macros:
                MacrosGoalFields(goals: Bindable(goals))
            }
        }
        .navigationTitle("Goals")
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: goals) { save() }
        .onChange(of: goals.macros) { save() }
    }

    private func save() {
        do {
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            AppLogger.new(for: GoalsView.self)
                .error("Failed to save model: \(error)")
        }
    }
}

// MARK: - Calorie Goal View
// ============================================================================

public struct CalorieGoalView: View {
    @Environment(\.modelContext) private var context: ModelContext
    @Query.Singleton var goals: UserGoals
    public init(_ id: UUID) {
        self._goals = .init(id)
    }

    public var body: some View {
        Form {
            CalorieGoalFields(goals: Bindable(goals))
        }
        .navigationTitle("Calorie Goals")
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: goals) { save() }
    }

    private func save() {
        do {
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            AppLogger.new(for: CalorieGoalView.self)
                .error("Failed to save model: \(error)")
        }
    }
}

// MARK: - Macros Goal View
// ============================================================================

public struct MacrosGoalView: View {
    @Environment(\.modelContext) private var context: ModelContext
    @Query.Singleton var goals: UserGoals
    public init(_ id: UUID) {
        self._goals = .init(id)
    }

    public var body: some View {
        Form {
            MacrosGoalFields(goals: Bindable(goals))
        }
        .navigationTitle("Macros")
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: goals.macros) { save() }
    }

    private func save() {
        do {
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            AppLogger.new(for: MacrosGoalView.self)
                .error("Failed to save model: \(error)")
        }
    }
}

// MARK: - Calorie Goal Fields
// ============================================================================

struct CalorieGoalFields: View {
    @Bindable var goals: UserGoals
    @State private var budgetDataService: BudgetDataService

    init(goals: Bindable<UserGoals>) {
        _goals = goals
        _budgetDataService = State(
            initialValue: BudgetDataService(
                adjustment: goals.wrappedValue.adjustment,
                date: Date()
            ))
    }

    private var maintenance: Double? {
        budgetDataService.budgetService?.weight.maintenance
    }

    /// Budget = maintenance + adjustment. Editing budget back-calculates adjustment.
    private var budgetBinding: Binding<Double?> {
        Binding(
            get: {
                guard let m = maintenance else { return nil }
                return m + (goals.adjustment ?? 0)
            },
            set: {
                guard let m = maintenance, let newBudget = $0 else { return }
                goals.adjustment = newBudget - m
            }
        )
    }

    var body: some View {
        Section {
            RecordRow(
                field: MaintenanceFieldDefinition(),
                value: .constant(maintenance),
                isInternal: false
            )
            RecordRow(
                field: WeeklyMaintenanceFieldDefinition(),
                value: .constant(maintenance.map { $0 * 7 }),
                isInternal: false
            )
        } header: {
            Text("Maintenance")
        } footer: {
            Text("Estimated from your weight trend")
        }
        .onAppear {
            budgetDataService.startObserving(widgetId: "CalorieGoalView")
            Task { await budgetDataService.refresh() }
        }
        .onDisappear {
            budgetDataService.stopObserving(widgetId: "CalorieGoalView")
        }
        .task {
            await budgetDataService.refresh()
        }

        Section {
            RecordRow(
                field: CalorieAdjustmentFieldDefinition(),
                value: $goals.adjustment,
                isInternal: true,
                showSign: true
            )
            RecordRow(
                field: WeeklyCalorieAdjustmentFieldDefinition(),
                value: $goals.adjustment.scaled(by: 7),
                isInternal: true,
                showSign: true
            )
        } header: {
            Text("Goal Adjustment")
        } footer: {
            Text("Surplus or deficit applied to maintenance")
        }

        Section {
            RecordRow(
                field: BudgetFieldDefinition(),
                value: budgetBinding,
                isInternal: maintenance != nil
            )
            RecordRow(
                field: WeeklyBudgetFieldDefinition(),
                value: budgetBinding.scaled(by: 7),
                isInternal: maintenance != nil
            )
        } header: {
            Text("Budget")
        } footer: {
            Text("Daily target = maintenance + adjustment")
        }
    }
}

// MARK: - Macros Goal Fields
// ============================================================================

struct MacrosGoalFields: View {
    @Bindable var goals: UserGoals
    @State private var budgetDataService: BudgetDataService

    init(goals: Bindable<UserGoals>) {
        _goals = goals
        _budgetDataService = State(
            initialValue: BudgetDataService(
                adjustment: goals.wrappedValue.adjustment,
                date: Date()
            ))
    }

    private var baseBudget: Double? {
        budgetDataService.budgetService?.baseBudget
    }

    /// Protein budget in grams: (budget × protein% / 100) / 4.
    /// Editing grams back-calculates percentage.
    private var proteinGrams: Binding<Double?> {
        macroGramsBinding(for: macrosBinding.protein, caloriesPerGram: 4)
    }

    /// Carbs budget in grams: (budget × carbs% / 100) / 4.
    /// Editing grams back-calculates percentage.
    private var carbsGrams: Binding<Double?> {
        macroGramsBinding(for: macrosBinding.carbs, caloriesPerGram: 4)
    }

    /// Fat budget in grams: (budget × fat% / 100) / 9.
    /// Editing grams back-calculates percentage.
    private var fatGrams: Binding<Double?> {
        macroGramsBinding(for: macrosBinding.fat, caloriesPerGram: 9)
    }

    var body: some View {
        Section {
            RecordRow(
                field: ProteinPercentDefinition().withComputed {
                    100 - (goals.macros?.carbs ?? 0) - (goals.macros?.fat ?? 0)
                },
                value: macrosBinding.protein,
                isInternal: true
            )
            RecordRow(
                field: CarbsPercentDefinition().withComputed {
                    100 - (goals.macros?.protein ?? 0) - (goals.macros?.fat ?? 0)
                },
                value: macrosBinding.carbs,
                isInternal: true
            )
            RecordRow(
                field: FatPercentDefinition().withComputed {
                    100 - (goals.macros?.protein ?? 0) - (goals.macros?.carbs ?? 0)
                },
                value: macrosBinding.fat,
                isInternal: true
            )
        } header: {
            Text("Macros Breakdown")
        } footer: {
            Text("Percentage of your daily calorie budget")
        }
        .onAppear {
            budgetDataService.startObserving(widgetId: "MacrosGoalView")
            Task { await budgetDataService.refresh() }
        }
        .onDisappear {
            budgetDataService.stopObserving(widgetId: "MacrosGoalView")
        }
        .task {
            await budgetDataService.refresh()
        }

        Section {
            RecordRow(
                field: ProteinFieldDefinition(),
                value: proteinGrams,
                isInternal: baseBudget != nil
            )
            RecordRow(
                field: CarbsFieldDefinition(),
                value: carbsGrams,
                isInternal: baseBudget != nil
            )
            RecordRow(
                field: FatFieldDefinition(),
                value: fatGrams,
                isInternal: baseBudget != nil
            )
        } header: {
            Text("Daily Budget")
        } footer: {
            Text("Derived from calorie budget and macro percentages")
        }
    }

    private var macrosBinding:
        (
            protein: Binding<Double?>,
            carbs: Binding<Double?>,
            fat: Binding<Double?>
        )
    {
        let macros = $goals.macros.defaulted(to: .init())
        return (
            protein: macros.protein,
            carbs: macros.carbs,
            fat: macros.fat
        )
    }

    private func macroGramsBinding(
        for percentage: Binding<Double?>,
        caloriesPerGram: Double
    ) -> Binding<Double?> {
        Binding(
            get: {
                guard
                    let budget = baseBudget,
                    let pct = percentage.wrappedValue
                else { return nil }

                return (budget * pct / 100) / caloriesPerGram
            },
            set: { newGrams in
                guard let budget = baseBudget, budget > 0 else {
                    return
                }

                guard let newGrams else {
                    percentage.wrappedValue = nil
                    return
                }

                percentage.wrappedValue = (newGrams * caloriesPerGram / budget) * 100
            }
        )
    }
}