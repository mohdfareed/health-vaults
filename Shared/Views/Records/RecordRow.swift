import SwiftUI

struct RecordRow<Field: FieldDefinition, DetailContent: View>: View {
    let field: Field
    @LocalizedMeasurement var measurement: Measurement<Field.Unit>

    let isInternal: Bool
    let showPicker: Bool
    let showSign: Bool
    let computed: (() -> Double?)?

    @FocusState
    private var isActive: Bool
    @State private var hasAppeared: Bool = false
    @ViewBuilder let details: () -> DetailContent

    init(
        field: Field,
        value: Binding<Double?>,
        isInternal: Bool,
        showPicker: Bool = false,
        showSign: Bool = false,
        @ViewBuilder details: @escaping () -> DetailContent = { EmptyView() }
    ) {
        self.field = field
        self._measurement = field.measurement(value)
        self.isInternal = isInternal
        self.showPicker = showPicker
        self.showSign = showSign

        // Extract computed function from ComputedField if available
        self.computed = (field as? ComputedField)?.compute
        self.details = details
    }

    var body: some View {
        MeasurementField(
            validator: field.validator, format: field.formatter,
            showPicker: showPicker, showDoneButton: false,
            measurement: $measurement
        ) {
            DetailedRow(image: field.icon, tint: field.tint) {
                Text(String(localized: field.title))
            } subtitle: {
                if let computedValue = computed?(),
                    let baseValue = $measurement.baseValue,
                    abs(baseValue - computedValue) > .ulpOfOne
                {
                    Button {
                        $measurement.baseValue = computedValue
                    } label: {
                        computedButtonLabel(computedValue)
                    }
                    .textScale(.secondary)
                    .disabled(!isInternal)
                }

                Text(measurement.unit.symbol).textScale(.secondary)
            } details: {
                details().textScale(.secondary)
            }
        }
        .disabled(!isInternal)
        .focused($isActive)
        .animation(hasAppeared ? .default : nil, value: computed?())
        .onAppear {
            // Delay setting hasAppeared to avoid animating initial value changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppeared = true
            }
        }
        .toolbar {
            if isActive {
                ToolbarItemGroup(placement: .keyboard) {
                    // Sign button - only include if needed
                    if showSign {
                        Button("Invert", systemImage: "plusminus") {
                            if let current = $measurement.baseValue {
                                $measurement.baseValue = -current
                            }
                        }
                        .disabled(!isInternal)
                    }

                    // Computed button - only include if applicable
                    if let computedValue = computed?(),
                        let baseValue = $measurement.baseValue,
                        abs(baseValue - computedValue) > .ulpOfOne
                    {
                        Button {
                            $measurement.baseValue = computedValue
                        } label: {
                            computedButtonLabel(computedValue)
                        }
                        .fixedSize()
                        .fontDesign(.monospaced)
                    }

                    Spacer()

                    Button {
                        isActive = false
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
        .transaction { $0.animation = nil }  // Disable toolbar animations
        .animation(.default, value: $measurement.baseValue)
    }

    @ViewBuilder
    private func computedButtonLabel(_ computedValue: Double) -> some View {
        HStack(alignment: .center, spacing: 2) {
            let icon = Image(systemName: "function").asText
            Text("\(icon):").foregroundStyle(.indigo.secondary)

            $measurement.computedText(
                computedValue, format: field.formatter
            )
            .foregroundStyle(.indigo)
            .contentTransition(.numericText(value: computedValue))
        }
    }
}

// MARK: Convenience Initializers
// ============================================================================

extension RecordRow where DetailContent == EmptyView {
    init(
        field: Field,
        value: Binding<Double?>,
        isInternal: Bool,
        showPicker: Bool = false,
        showSign: Bool = false
    ) {
        self.init(
            field: field,
            value: value,
            isInternal: isInternal,
            showPicker: showPicker,
            showSign: showSign,
            details: { EmptyView() }
        )
    }
}

// MARK: Extensions
// ============================================================================

extension LocalizedMeasurement {
    func computedText(
        _ computed: Double, format: FloatingPointFormatStyle<Double>
    ) -> some View {
        let measurement = Measurement(
            value: computed, unit: self.definition.baseUnit
        ).converted(to: self.unit.wrappedValue ?? self.definition.baseUnit)

        let value = measurement.value.formatted(format)
        return Text(value)
    }
}
