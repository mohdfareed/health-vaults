import SwiftData
import SwiftUI

// MARK: - Macros Goal Fields
// ============================================================================

public struct MacrosGoalFields: View {
    @Bindable var goals: UserGoals
    @State private var budgetDataService: BudgetDataService

    public init(goals: Bindable<UserGoals>) {
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

    /// Protein budget in grams: (budget x protein% / 100) / 4.
    /// Editing grams back-calculates percentage.
    private var proteinGrams: Binding<Double?> {
        macroGramsBinding(for: macrosBinding.protein, caloriesPerGram: 4)
    }

    /// Carbs budget in grams: (budget x carbs% / 100) / 4.
    /// Editing grams back-calculates percentage.
    private var carbsGrams: Binding<Double?> {
        macroGramsBinding(for: macrosBinding.carbs, caloriesPerGram: 4)
    }

    /// Fat budget in grams: (budget x fat% / 100) / 9.
    /// Editing grams back-calculates percentage.
    private var fatGrams: Binding<Double?> {
        macroGramsBinding(for: macrosBinding.fat, caloriesPerGram: 9)
    }

    public var body: some View {
        Section {
            RecordRow(
                field: BudgetFieldDefinition(),
                value: .constant(baseBudget),
                isInternal: false
            )
        } header: {
            Text("Calorie Budget")
        }

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
            Text("Percentage of your daily calorie budget.")
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
            Text("Derived from calorie budget and macro percentages.")
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
