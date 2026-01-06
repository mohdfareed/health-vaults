import SwiftUI
import WidgetKit

// MARK: Locale
// ============================================================================

/// A property wrapper to access the app's locale, applying any user settings.
@MainActor @propertyWrapper
public struct AppLocale: DynamicProperty {
    @AppStorage(.unitSystem, store: SharedDefaults) private var unitSystem: MeasurementSystem?
    @AppStorage(.firstDayOfWeek, store: SharedDefaults) private var firstDayOfWeek: Weekday?
    @Environment(\.locale) private var systemLocale: Locale

    public init() {}

    /// The computed locale combining system and user settings.
    public var wrappedValue: Locale {
        var components = Locale.Components(locale: systemLocale)
        components.firstDayOfWeek = firstDayOfWeek ?? components.firstDayOfWeek
        components.measurementSystem = unitSystem ?? components.measurementSystem
        return Locale(components: components)
    }

    /// Exposes bindings to user settings for use in SwiftUI.
    public var projectedValue: AppLocale { self }

    /// Binding for measurement system setting.
    public var units: Binding<MeasurementSystem?> {
        Binding(
            get: { unitSystem },
            set: {
                unitSystem = $0
                WidgetCenter.shared.reloadAllTimelines()
            }
        )
    }

    /// Binding for first day of week setting.
    public var firstWeekDay: Binding<Weekday?> {
        Binding(
            get: { firstDayOfWeek },
            set: {
                firstDayOfWeek = $0
                WidgetCenter.shared.reloadAllTimelines()
            }
        )
    }
}
