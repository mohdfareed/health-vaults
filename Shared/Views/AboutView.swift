import HealthKit
import SwiftUI

public struct AboutView: View {
    @Environment(\.healthKit) private var healthKit

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                // Apple Health Integration
                Section {
                    // Apple Health Header
                    HStack(spacing: 16) {
                        Image.appleHealthLogo
                            .frame(height: 48)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Health Integration")
                                .font(.headline)
                                .fontWeight(.medium)
                            Text(
                                """
                                HealthVaults uses Apple Health data to show your metrics, trends, and progress.
                                """
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Privacy Information
                    Text(
                        """
                        Health data is stored and managed by Apple Health.
                        HealthVaults does not keep a separate local copy of your health entries.
                        You can manage access in Apple Health:
                        Settings > Apps > Health > Data Access & Devices > \(AppName)
                        """
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }.listRowSeparator(.hidden)

                // Credits & Licenses Section
                Section {
                    CreditRow(
                        service: "Icons8",
                        description: "Custom app icons and symbols",
                        url: "https://icons8.com"
                    )
                } header: {
                    Text("Credits & Licenses")
                }

                // App Information Section
                Section {
                    AppInfoRow(
                        title: "Version",
                        value: appVersion,
                        systemImage: "app.badge"
                    )

                    AppInfoRow(
                        title: "Build",
                        value: buildNumber,
                        systemImage: "hammer"
                    )

                    AppInfoRow(
                        title: "Developer",
                        value: "Mohammed Fareed",
                        systemImage: "person.circle"
                    )
                } header: {
                    Text("App Information")
                }

                // Source Code Section
                Section {
                    Link(destination: URL(string: RepoURL)!) {
                        LabeledContent {
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(Color.accent)
                        } label: {
                            Label(
                                "Source Code",
                                systemImage: "chevron.left.slash.chevron.right"
                            )
                        }
                    }
                }
            }
            .navigationTitle("About")
        }
    }

    // MARK: - Helper Properties

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            ?? "Unknown"
    }
}

// MARK: - Supporting Views

struct AppInfoRow: View {
    let title: String.LocalizationValue
    let value: String
    let systemImage: String

    var body: some View {
        LabeledContent {
            Text(value)
        } label: {
            Label {
                Text(String(localized: title))
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }
}

struct CreditRow: View {
    let service: String
    let description: String?
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            LabeledContent {
                Image(systemName: "arrow.up.right")
            } label: {
                Text(service)
                if let description = description {
                    Text(description)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

public struct HealthPermissionsManager: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var authStatus: HealthAuthorizationStatus = .noAccess

    let service: HealthKitService
    public init(service: HealthKitService) {
        self.service = service
    }

    public var body: some View {
        Button {
            service.requestAuthorization {
                refreshAuthStatus()
            }
        } label: {
            Label {
                HStack {
                    Text("Health Permissions")
                        .foregroundStyle(Color.primary)
                    Spacer()
                    statusView
                }
            } icon: {
                Image.healthKit
                    .foregroundStyle(Color.healthKit)
            }
        }
        .animation(.smooth, value: authStatus)
        .onAppear {
            refreshAuthStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshAuthStatus()
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch authStatus {
        case .noAccess:
            Text("None")
                .foregroundStyle(Color.secondary)
                .contentTransition(.opacity)
            Image(systemName: "xmark.circle.fill")
                .imageScale(.large)
                .foregroundStyle(Color.red)
                .contentTransition(.symbolEffect(.replace))
        case .authorized:
            Image(systemName: "checkmark.circle.fill")
                .imageScale(.large)
                .foregroundStyle(Color.green)
                .contentTransition(.symbolEffect(.replace))
        case .partiallyAuthorized:
            Text("Partial")
                .foregroundStyle(Color.secondary)
                .contentTransition(.opacity)
            Image(systemName: "exclamationmark.circle.fill")
                .imageScale(.large)
                .foregroundStyle(Color.yellow)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    private func refreshAuthStatus() {
        withAnimation(.smooth) {
            authStatus = service.authorizationStatus()
        }
    }
}
