import SwiftData
import SwiftUI
import WidgetKit

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

    /// Protein budget in grams: (budget × protein% / 100) / 4
    private var proteinGrams: Double? {
        guard let budget = baseBudget,
              let pct = goals.macros?.protein else { return nil }
        return (budget * pct / 100) / 4
    }

    /// Carbs budget in grams: (budget × carbs% / 100) / 4
    private var carbsGrams: Double? {
        guard let budget = baseBudget,
              let pct = goals.macros?.carbs else { return nil }
        return (budget * pct / 100) / 4
    }

    /// Fat budget in grams: (budget × fat% / 100) / 9
    private var fatGrams: Double? {
        guard let budget = baseBudget,
              let pct = goals.macros?.fat else { return nil }
        return (budget * pct / 100) / 9
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
                value: .constant(proteinGrams),
                isInternal: false
            )
            RecordRow(
                field: CarbsFieldDefinition(),
                value: .constant(carbsGrams),
                isInternal: false
            )
            RecordRow(
                field: FatFieldDefinition(),
                value: .constant(fatGrams),
                isInternal: false
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
}