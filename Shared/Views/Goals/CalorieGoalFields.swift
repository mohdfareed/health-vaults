import SwiftData
import SwiftUI

// MARK: - Calorie Goal Fields
// ============================================================================

public struct CalorieGoalFields: View {
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

    public var body: some View {
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
            Text("Estimated from your weight trend.")
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
            Text("Surplus or deficit applied to maintenance.")
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
            Text("Daily target = maintenance + adjustment.")
        }
    }
}
