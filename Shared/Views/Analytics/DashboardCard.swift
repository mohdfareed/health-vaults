import SwiftData
import SwiftUI

// MARK: - Dashboard Card
// ============================================================================

public struct DashboardCard<Content: View, Destination: View>: View {
    let title: String.LocalizationValue
    let icon: Image
    let color: Color
    let footer: String?

    @ViewBuilder let content: Content
    @ViewBuilder let destination: Destination

    public init(
        title: String.LocalizationValue,
        icon: Image,
        color: Color,
        footer: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.footer = footer
        self.content = content()
        self.destination = destination()
    }

    public var body: some View {
        Section {
            content
                .padding(.vertical, 4)
        } header: {
            Text(String(localized: title))
        } footer: {
            if let footer {
                Text(footer)
            }
        }
        .fontDesign(.rounded)
    }
}

// MARK: - Progress View
// ============================================================================

struct MetricBar: View {
    let title: String.LocalizationValue
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: title))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }

            ProgressView(value: value)
                .progressViewStyle(.circular)
                .tint(color)
        }
    }
}
