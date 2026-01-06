import HealthVaultsShared
import SwiftData
import SwiftUI

// TODO: Add haptics and animations
// TODO: Add welcome screen for new users
// TODO: Add views to check which data points are taken into account for metrics and budgets
//       This could be charts, could be lists, could be math summaries

// FIXME: Debug warning:
// containerToPush is nil, will not push anything to candidate receiver for request token: BF2ABD30

// FIXME: Debug info:
// void * _Nullable NSMapGet(NSMapTable * _Nonnull, const void * _Nullable): map table argument is NULL

struct AppView: View {
    @AppStorage(.theme, store: SharedDefaults)
    private var theme: AppTheme
    @AppStorage(.userGoals, store: SharedDefaults)
    private var goalsID: UUID

    @Environment(\.colorScheme)
    private var colorScheme: ColorScheme
    @AppLocale private var locale: Locale

    @Environment(\.healthKit)
    private var healthKitService

    @State private var activeDataModel: HealthDataModel? = nil

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.xaxis") {
                DashboardView(goalsID: goalsID)
            }

            Tab("Data", systemImage: "heart.text.clipboard.fill") {
                HealthDataView()
            }

            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
        .environment(\.locale, self.locale)
        .preferredColorScheme(self.theme.colorScheme)

        .animation(.default, value: self.theme)
        .animation(.default, value: self.colorScheme)
        .animation(.default, value: self.locale)

        .contentTransition(.symbolEffect(.replace))
        .contentTransition(.numericText())
        .contentTransition(.opacity)
        .onAppear {
            healthKitService.requestAuthorization()
        }

        .overlay(alignment: .bottomTrailing) {
            AddMenu { dataModel in
                activeDataModel = dataModel
            }
            .padding(.bottom, 64)
            .padding(.trailing, 8)
        }

        .sheet(item: $activeDataModel) { dataModel in
            NavigationStack {
                dataModel.createForm(formType: .create)
            }
        }
    }
}
