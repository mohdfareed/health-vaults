import HealthVaultsShared
import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

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
    @State private var isKeyboardVisible: Bool = false

        private var effectivePreferredColorScheme: ColorScheme? {
    #if os(iOS)
        nil
    #else
        self.theme.colorScheme
    #endif
        }

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "heart.gauge.open") {
                DashboardView(goalsID: goalsID)
            }

            Tab("Goals", systemImage: "target") {
                NavigationStack {
                    GoalsView(goalsID)
                }
            }

            Tab("Data", systemImage: "heart.text.clipboard") {
                HealthDataView()
            }

            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
        .environment(\.locale, self.locale)
        .preferredColorScheme(effectivePreferredColorScheme)

        .animation(.default, value: self.theme)
        .animation(.smooth(duration: 0.35), value: self.theme.colorScheme)
        .animation(.default, value: self.colorScheme)
        .animation(.default, value: self.locale)

        .contentTransition(.symbolEffect(.replace))
        .contentTransition(.numericText())
        .contentTransition(.opacity)
        .onAppear {
            healthKitService.requestAuthorization()
#if os(iOS)
            applyThemeStyle(theme, animated: false)
#endif
        }

#if os(iOS)
        .onChange(of: theme) { _, newTheme in
            applyThemeStyle(newTheme, animated: true)
        }
#endif

        .overlay(alignment: .bottomTrailing) {
            AddMenu { dataModel in
                activeDataModel = dataModel
            }
            .padding(.bottom, 64)
            .padding(.trailing, 8)
            .opacity(isKeyboardVisible ? 0 : 1)
            .allowsHitTesting(!isKeyboardVisible)
            .animation(.easeInOut(duration: 0.2), value: isKeyboardVisible)
        }

        #if os(iOS)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillShowNotification
                )
            ) { _ in
                isKeyboardVisible = true
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillHideNotification
                )
            ) { _ in
                isKeyboardVisible = false
            }
        #endif

        .sheet(item: $activeDataModel) { dataModel in
            NavigationStack {
                dataModel.createForm(formType: .create)
            }
        }
    }
}

#if os(iOS)
extension AppView {
    private func applyThemeStyle(_ theme: AppTheme, animated: Bool) {
        guard
            let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let window = scene.windows.first(where: \.isKeyWindow)
        else {
            return
        }

        let style: UIUserInterfaceStyle
        switch theme {
        case .light:
            style = .light
        case .dark:
            style = .dark
        case .system:
            style = .unspecified
        }

        let applyStyle = {
            window.overrideUserInterfaceStyle = style
        }

        guard animated else {
            applyStyle()
            return
        }

        UIView.transition(
            with: window,
            duration: 0.35,
            options: [.transitionCrossDissolve, .allowAnimatedContent]
        ) {
            applyStyle()
        }
    }
}
#endif
