import SwiftUI

struct MeasurementField<Unit: Dimension, Content: View>: View {
    @Environment(\.isEnabled) private var enabled

    let validator: ((Double) -> Bool)?
    let format: FloatingPointFormatStyle<Double>
    let showPicker: Bool

    @LocalizedMeasurement
    var measurement: Measurement<Unit>
    @ViewBuilder
    var label: () -> Content

    @FocusState
    private var isActive: Bool
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
                    TextField("—", value: $measurement.value, format: format)
                        .focused($isActive)
                        .disabled(!enabled)
                        .foregroundStyle(enabled ? .primary : .tertiary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: true, vertical: true)

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

            // FIXME: throws debug errors (along with computedButton)
            // error: Invalid frame dimension (negative or non-finite).
            .toolbar(
                content: {
                    ToolbarItemGroup(placement: .keyboard) {
                        if isActive {
                            Spacer()
                            Button("Done", systemImage: "checkmark") {
                                withAnimation(.default) {
                                    isActive = false
                                }
                            }
                            .foregroundColor(.accent)
                        }
                    }
                }
            )

            // Trap all taps when not active
            Color.clear.contentShape(Rectangle())
                .onTapGesture {
                    if !isActive {
                        withAnimation { isActive = true }
                    }
                }
                .allowsHitTesting(!isActive)
        }

        .onChange(of: $measurement.baseValue) {
            if !isValid {
                withAnimation(.default) {
                    $measurement.baseValue = nil
                }
            }
        }

        .animation(.default, value: $measurement.baseValue)
        .animation(.default, value: $measurement.displayUnit)
        .animation(.default, value: enabled)
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
}
