import HealthVaultsShared
import SwiftData
import SwiftUI

// TODO: Animate changing theme

struct SettingsView: View {
    @Environment(\.modelContext)
    internal var context: ModelContext
    @Environment(\.colorScheme)
    internal var colorScheme: ColorScheme
    @Environment(\.healthKit)
    internal var healthKit: HealthKitService

    @AppStorage(.userGoals, store: SharedDefaults) var goalsID: UUID
    @AppStorage(.theme, store: SharedDefaults) var theme: AppTheme

    @AppLocale private var locale
    @State private var reset = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("General Settings")) {
                    generalSettings
                }

                GoalView(goalsID).animation(.default, value: goalsID)

                Section {
                    HealthPermissionsManager(service: healthKit)
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text(
                        """
                        Manage permissions for accessing health data at:
                        Settings > Privacy & Security > Health > \(AppName)
                        """
                    )
                }

                Section {
                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
                    }

                    Button(action: { reset = true }) {
                        Label {
                            Text("Reset Settings")
                                .foregroundStyle(.red)
                        } icon: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .scrollDismissesKeyboard(.interactively)
            .resetAlert(isPresented: $reset)
        }
    }

    @ViewBuilder var generalSettings: some View {
        Picker(
            "Theme",
            systemImage: colorScheme == .light
                ? "sun.max.fill"
                : "moon.fill",
            selection: self.$theme,
            content: {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    if theme != .system {
                        Text(theme.localized).tag(theme)
                    }
                }

                Divider()
                Label {
                    Text("System")
                } icon: {
                }.tag(AppTheme.system)
            }
        ) { Text(self.theme.localized).fixedSize() }
        .frame(maxHeight: 8)
        .contentTransition(.identity)
        .transaction { $0.animation = nil }

        Picker(
            "Measurements", systemImage: "ruler",
            selection: self.$locale.units,
            content: {
                let systems = MeasurementSystem.measurementSystems
                ForEach(systems, id: \.self) { system in
                    Text(system.localized).tag(system)
                }
                Divider()
                Label {
                    Text("System")
                } icon: {
                }.tag(nil as MeasurementSystem?)
            },
        ) {
            if self.$locale.units.wrappedValue == nil {
                Text("System").fixedSize()
            } else {
                Text(self.locale.measurementSystem.localized).fixedSize()
            }
        }
        .frame(maxHeight: 8)
        .contentTransition(.identity)
        .transaction { $0.animation = nil }

        Picker(
            "First Weekday", systemImage: "calendar",
            selection: self.$locale.firstWeekDay,
            content: {
                ForEach(Weekday.allCases, id: \.self) { weekday in
                    Text(weekday.localized).tag(weekday)
                }
                Divider()
                Label {
                    Text("System")
                } icon: {
                }.tag(nil as Weekday?)
            }
        ) {
            if self.$locale.firstWeekDay.wrappedValue == nil {
                Text("System").fixedSize()
            } else {
                Text(self.locale.firstDayOfWeek.abbreviated).fixedSize()
            }
        }
        .frame(maxHeight: 8)
        .contentTransition(.identity)
        .transaction { $0.animation = nil }
    }
}

extension View {
    fileprivate func resetAlert(isPresented: Binding<Bool>) -> some View {
        self.alert("Reset All Settings", isPresented: isPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                SharedDefaults.resetSettings()
            }
        } message: {
            Text(
                """
                Reset all settings to their default values.
                This action cannot be undone.
                """
            )
        }
    }
}
