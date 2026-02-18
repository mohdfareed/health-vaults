import SwiftUI

// MARK: Colors
// ============================================================================

extension Color {
    public static var accent: Color { .init("Accent") }
    public static var healthKit: Color { .pink }
    public static var shortcuts: Color { .purple }
    public static var foodNoms: Color { .calories }
    public static var unknown: Color { .gray }

    // Data Records
    public static var calories: Color { .init("Calorie") }
    public static var weight: Color { .purple }
    public static var bodyFat: Color { .weight }

    // Dietary Energy
    public static var macros: Color { .indigo }
    public static var protein: Color {
        Color.red.mix(with: .brown, by: 0.1).mix(with: .black, by: 0.2)
    }
    public static var carbs: Color { .orange }
    public static var fat: Color { .green }
    public static var alcohol: Color { .indigo }

    // Widget
    public static var widgetBackground: Color { .init("WidgetBackground") }
}

// MARK: Iconography
// ============================================================================

extension Image {
    public static var logo: Image { .init("logo.fill") }

    // Apple Health
    public static var appleHealth: Image { .init("AppleHealth") }
    public static var appleHealthBadge: Image { .init("AppleHealthBadge") }

    // Data Sources
    public static var healthKit: Image { .init(systemName: "heart.fill") }
    public static var shortcuts: Image {
        .init(systemName: "app.connected.to.app.below.fill")
            .symbolRenderingMode(.hierarchical)
    }
    public static var foodNoms: Image { .init(systemName: "fork.knife") }
    public static var unknownApp: Image {
        .init(systemName: "questionmark.app.dashed")
            .symbolRenderingMode(.hierarchical)
    }

    // Data Records
    public static var calories: Image { .init(systemName: "flame.fill") }
    public static var weight: Image { .init(systemName: "figure") }
    public static var bodyFat: Image { .init(systemName: "percent") }
    public static var maintenance: Image {
        .init(systemName: "flame.gauge.open")
            .symbolRenderingMode(.hierarchical)
    }
    public static var credit: Image {
        .init(systemName: "creditcard.circle")
            .symbolRenderingMode(.hierarchical)
    }

    // Dietary Energy
    public static var macros: Image { .init(systemName: "chart.pie") }
    public static var protein: Image { .init("meat").symbolRenderingMode(.hierarchical) }
    public static var fat: Image { .init("avocado").symbolRenderingMode(.hierarchical) }
    public static var carbs: Image { .init("bread").symbolRenderingMode(.hierarchical) }
    public static var alcohol: Image { .init(systemName: "wineglass") }
}

// MARK: Miscellaneous
// ============================================================================
extension Image {
    public static var appleHealthLogo: some View {
        Image.appleHealth
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 48)
            .padding(1).background(.quinary)  // Stroke
            .cornerRadius(12)  // Stroke corner radius
    }
}

extension DataSource {
    public var icon: Image {
        switch self {
        case .app:
            return .logo
        case .healthKit:
            return .healthKit
        case .shortcuts:
            return .shortcuts
        case .foodNoms:
            return .foodNoms
        case .other:
            return .unknownApp
        }
    }

    public var color: Color {
        switch self {
        case .app:
            return .accent
        case .healthKit:
            return .healthKit
        case .shortcuts:
            return .shortcuts
        case .foodNoms:
            return .foodNoms
        case .other:
            return .unknown
        }
    }
}

// MARK: Extensions
// ============================================================================

extension Image {
    var asText: Text {
        Text("\(self)").font(.footnote.bold())
    }
}
