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
            DashboardWidgets(goals)
                .navigationTitle("Dashboard")
        }
    }
}

struct DashboardWidgets: View {
    private let goals: UserGoals

    init(_ goals: UserGoals) {
        self.goals = goals
    }

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
            }

            DashboardCard(
                title: "Macros", icon: .macros, color: .macros
            ) {
                MacrosComponent(
                    adjustment: goals.adjustment,
                    macroAdjustments: goals.macros,
                    date: Date()
                )
            } destination: {
            }

            OverviewComponent(
                adjustment: goals.adjustment,
                macroAdjustments: goals.macros,
                date: Date()
            )
        }
    }
}
