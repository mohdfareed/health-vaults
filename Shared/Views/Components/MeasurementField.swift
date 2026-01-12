import SwiftUI

struct MeasurementField<Unit: Dimension, Content: View>: View {
    @Environment(\.isEnabled) private var enabled

    let validator: ((Double) -> Bool)?
    let format: FloatingPointFormatStyle<Double>
    let showPicker: Bool
    let showDoneButton: Bool

    @LocalizedMeasurement
    var measurement: Measurement<Unit>
    @ViewBuilder
    var label: () -> Content

    @FocusState
    private var isActive: Bool
    @State private var textValue: String = ""
    @State private var hasAppeared: Bool = false

    init(
        validator: ((Double) -> Bool)?,
        format: FloatingPointFormatStyle<Double>,
        showPicker: Bool,
        showDoneButton: Bool = true,
        measurement: LocalizedMeasurement<Unit>,
        @ViewBuilder label: @escaping () -> Content
    ) {
        self.validator = validator
        self.format = format
        self.showPicker = showPicker
        self.showDoneButton = showDoneButton
        self._measurement = measurement
        self.label = label
    }

    private var isValid: Bool {
        guard let value = $measurement.baseValue,
            let validator = validator
        else { return true }
        return validator(value)
    }

    var body: some View {
        ZStack {
            LabeledContent {
                HStack(alignment: .center, spacing: 4) {
                    TextField("—", text: $textValue)
                        .focused($isActive)
                        .disabled(!enabled)
                        .foregroundStyle(enabled ? .primary : .tertiary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: true, vertical: true)
                        .onChange(of: isActive) { wasActive, nowActive in
                            if nowActive {
                                // Entering edit: show raw value without trailing zeros
                                if $measurement.baseValue != nil {
                                    textValue = formatForEditing(measurement.value)
                                } else {
                                    textValue = ""
                                }
                            } else {
                                // Leaving edit: parse and apply formatted value
                                commitTextValue()
                            }
                        }
                        .onChange(of: textValue) {
                            // Live update while typing (without reformatting)
                            if isActive, let parsed = parseDecimal(textValue) {
                                $measurement.value.wrappedValue = parsed
                            }
                        }
                        .onAppear {
                            // Initialize display text
                            if $measurement.baseValue != nil {
                                textValue = measurement.value.formatted(format)
                            }
                        }
                        .onChange(of: $measurement.baseValue) { oldValue, newValue in
                            // Update display when value changes externally
                            if isActive {
                                // While editing: only update if change came from outside (toolbar buttons)
                                // Check if the current textValue doesn't match the new value
                                if let newValue, parseDecimal(textValue) != newValue {
                                    textValue = formatForEditing(measurement.value)
                                } else if newValue == nil {
                                    textValue = ""
                                }
                            } else {
                                // Not editing: apply full format
                                if newValue != nil {
                                    textValue = measurement.value.formatted(format)
                                } else {
                                    textValue = ""
                                }
                            }
                        }

                        #if os(iOS)
                            .keyboardType(.decimalPad)
                            .onReceive(
                                NotificationCenter.default.publisher(
                                    for: UITextField.textDidBeginEditingNotification
                                )
                            ) { notification in
                                guard let textField = notification.object as? UITextField else {
                                    return
                                }

                                textField.selectedTextRange = textField.textRange(
                                    from: textField.beginningOfDocument,
                                    to: textField.endOfDocument
                                )
                            }
                        #endif

                    if showPicker && $measurement.availableUnits().count > 1 {
                        picker.frame(maxWidth: 12).fixedSize()
                    }
                }.layoutPriority(-1)
            } label: {
                label()
            }

            // Trap all taps when not active
            if !isActive {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation { isActive = true }
                    }
            }
        }
        .toolbar {
            // Only contribute toolbar items when THIS field is focused
            if showDoneButton && isActive {
                ToolbarItemGroup(placement: .keyboard) {
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

        .animation(hasAppeared ? .default : nil, value: $measurement.baseValue)
        .animation(hasAppeared ? .default : nil, value: $measurement.displayUnit)
        .animation(hasAppeared ? .default : nil, value: enabled)
        .onAppear {
            // Delay setting hasAppeared to avoid animating initial value changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppeared = true
            }
        }
    }

    private var picker: some View {
        Picker("", selection: $measurement.unit) {
            ForEach($measurement.availableUnits(), id: \.self) {
                Text(
                    measurement.converted(to: $0).formatted(
                        .measurement(
                            width: .wide, usage: .asProvided,
                            numberFormatStyle: format
                        )
                    )
                ).tag($0)
            }

            Divider()
            Label {
                Text("Default")
            } icon: {
                Image(systemName: "arrow.clockwise")
            }.tag(nil as Unit?)
        } currentValueLabel: {
            // Only show picker chevron icon
        }
        .labelsHidden()
        .animation(.default, value: $measurement.unit.wrappedValue)
    }

    // MARK: - Text Editing Helpers

    /// Format value for editing - removes unnecessary trailing zeros
    private func formatForEditing(_ value: Double) -> String {
        // Use a simple format that doesn't add trailing zeros
        let formatted = String(format: "%g", value)
        return formatted
    }

    /// Parse decimal input, handling locale-specific separators
    private func parseDecimal(_ text: String) -> Double? {
        // Try parsing with current locale first
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current

        if let number = formatter.number(from: text) {
            return number.doubleValue
        }

        // Fallback: try standard decimal point
        return Double(text.replacingOccurrences(of: ",", with: "."))
    }

    /// Commit the text value to the measurement
    private func commitTextValue() {
        if textValue.isEmpty {
            $measurement.value.wrappedValue = nil
        } else if let parsed = parseDecimal(textValue) {
            // Validate on commit - if invalid, clear the value
            if let validator = validator, !validator(parsed) {
                withAnimation(.default) {
                    $measurement.value.wrappedValue = nil
                    textValue = ""
                }
            } else {
                $measurement.value.wrappedValue = parsed
                // Update display with formatted value
                textValue = parsed.formatted(format)
            }
        } else {
            // Invalid input - restore previous value
            if $measurement.baseValue != nil {
                textValue = measurement.value.formatted(format)
            } else {
                textValue = ""
            }
        }
    }
}
