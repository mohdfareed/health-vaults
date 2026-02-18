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
    @AppStorage(.firstDayOfWeek, store: SharedDefaults) private var firstWeekday: Weekday?

    private var budgetFooter: String {
        let calendar = Calendar.autoupdatingCurrent
        let targetWeekday = firstWeekday?.calendarValue ?? calendar.firstWeekday
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)
        let offset = (targetWeekday - todayWeekday + 7) % 7
        let daysRemaining = max(1, offset == 0 ? 7 : offset)

        return
            "Today’s budget = daily budget + (credit ÷ \(daysRemaining)).\nDays remaining this week: \(daysRemaining)."
    }

    var body: some View {
        List {
            DashboardCard(
                title: "Calories", icon: .calories, color: .calories,
                footer: budgetFooter
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
                title: "Macros", icon: .macros, color: .macros
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
