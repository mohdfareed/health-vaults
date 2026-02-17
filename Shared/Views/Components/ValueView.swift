import Foundation
import SwiftUI

/// A simple view that displays a measurement value with an icon and optional tint
struct ValueView<Unit: Dimension>: View {
    @LocalizedMeasurement var measurement: Measurement<Unit>
    let icon: Image?
    let tint: Color?
    let format: FloatingPointFormatStyle<Double>
    let label: String?

    init(
        measurement: LocalizedMeasurement<Unit>,
        icon: Image?,
        tint: Color?,
        format: FloatingPointFormatStyle<Double>,
        label: String? = nil
    ) {
        _measurement = measurement
        self.icon = icon
        self.tint = tint
        self.format = format
        self.label = label
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            icon?.asText.foregroundStyle(tint ?? .primary)
            Text(measurement.value, format: format)
                .animation(.default, value: measurement.value)
                .contentTransition(.numericText(value: measurement.value))
            Text(label ?? measurement.unit.symbol)
                .textScale(.secondary)
                .foregroundStyle(.secondary)
        }
    }
}
