import HealthVaultsShared
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query.Singleton var goals: UserGoals

    init(goalsID: UUID) {
        self._goals = .init(goalsID)
    }

    var body: some View {
        NavigationStack {
            DashboardWidgets(goals: goals)
                .navigationTitle("Dashboard")
        }
    }
}

struct DashboardWidgets: View {
    @Bindable var goals: UserGoals

    var body: some View {
        List {
            DashboardCard(
                title: "Calories", icon: .calories, color: .calories
            ) {
                BudgetComponent(
                    adjustment: goals.adjustment,
                    date: Date()
                )
            } destination: {
                OverviewComponent(
                    adjustment: goals.adjustment,
                    macroAdjustments: goals.macros,
                    date: Date(),
                    focus: .calories
                )
            }

            DashboardCard(
                title: "Macros",
                icon: .macros,
                color: .macros
            ) {
                MacrosComponent(
                    adjustment: goals.adjustment,
                    macroAdjustments: goals.macros,
                    date: Date()
                )
            } destination: {
                OverviewComponent(
                    adjustment: goals.adjustment,
                    macroAdjustments: goals.macros,
                    date: Date(),
                    focus: .macros
                )
            }
        }
    }
}
