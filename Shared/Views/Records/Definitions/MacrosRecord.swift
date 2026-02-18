import Foundation
import SwiftUI

// MARK: - Field Definitions

struct ProteinFieldDefinition: FieldDefinition {
    typealias Unit = UnitMass

    let title: String.LocalizationValue = "Protein"
    let icon = Image.protein
    let tint = Color.protein
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    let validator: (@Sendable (Double) -> Bool)? = { $0 >= 0 }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitMass> {
        LocalizedMeasurement(binding, definition: UnitDefinition.macro)
    }
}

struct ProteinPercentDefinition: FieldDefinition {
    typealias Unit = UnitMass

    let title: String.LocalizationValue = "Protein"
    let icon = Image.protein
    let tint = Color.protein
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    let validator: (@Sendable (Double) -> Bool)? = { $0 >= 0 && $0 <= 100 }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitMass> {
        LocalizedMeasurement(binding, definition: UnitDefinition.percentage)
    }
}

struct CarbsFieldDefinition: FieldDefinition {
    typealias Unit = UnitMass

    let title: String.LocalizationValue = "Carbs"
    let icon = Image.carbs
    let tint = Color.carbs
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    let validator: (@Sendable (Double) -> Bool)? = { $0 >= 0 }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitMass> {
        LocalizedMeasurement(binding, definition: UnitDefinition.macro)
    }
}

struct CarbsPercentDefinition: FieldDefinition {
    typealias Unit = UnitMass

    let title: String.LocalizationValue = "Carbs"
    let icon = Image.carbs
    let tint = Color.carbs
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    let validator: (@Sendable (Double) -> Bool)? = { $0 >= 0 && $0 <= 100 }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitMass> {
        LocalizedMeasurement(binding, definition: UnitDefinition.percentage)
    }
}

struct FatFieldDefinition: FieldDefinition {
    typealias Unit = UnitMass

    let title: String.LocalizationValue = "Fat"
    let icon = Image.fat
    let tint = Color.fat
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    let validator: (@Sendable (Double) -> Bool)? = { $0 >= 0 }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitMass> {
        LocalizedMeasurement(binding, definition: UnitDefinition.macro)
    }
}

struct FatPercentDefinition: FieldDefinition {
    typealias Unit = UnitMass

    let title: String.LocalizationValue = "Fat"
    let icon = Image.fat
    let tint = Color.fat
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    let validator: (@Sendable (Double) -> Bool)? = { $0 >= 0 && $0 <= 100 }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitMass> {
        LocalizedMeasurement(binding, definition: UnitDefinition.percentage)
    }
}

struct AlcoholFieldDefinition: FieldDefinition {
    typealias Unit = UnitVolume

    let title: String.LocalizationValue = "Alcohol"
    let icon = Image.alcohol
    let tint = Color.alcohol
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    let validator: (@Sendable (Double) -> Bool)? = { $0 >= 0 }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitVolume> {
        LocalizedMeasurement(binding, definition: UnitDefinition.alcohol)
    }
}

// MARK: - Helper Views for Row Subtitles

struct MacroValueView: View {
    let value: Double?
    let field: any FieldDefinition

    var body: some View {
        if let value = value {
            ValueView(
                measurement: .init(
                    baseValue: .constant(value),
                    definition: UnitDefinition.macro
                ),
                icon: field.icon, tint: field.tint,
                format: field.formatter,
                label: ""
            )
            .textScale(.secondary)
            .imageScale(.small)
            .symbolVariant(.fill)
        }
    }
}

struct AlcoholValueView: View {
    let value: Double?
    let field: AlcoholFieldDefinition

    var body: some View {
        if let value = value {
            ValueView(
                measurement: .init(
                    baseValue: .constant(value),
                    definition: UnitDefinition.alcohol
                ),
                icon: field.icon, tint: field.tint,
                format: field.formatter,
                label: ""
            )
            .textScale(.secondary)
            .imageScale(.small)
            .symbolVariant(.fill)
        }
    }
}
