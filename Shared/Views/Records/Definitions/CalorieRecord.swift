import Foundation
import SwiftUI

// MARK: - Field Definitions

/// Calorie field definition
struct CalorieFieldDefinition: FieldDefinition {
    typealias Unit = UnitEnergy

    let title: String.LocalizationValue = "Calories"
    let icon = Image.calories
    let tint = Color.calories
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    let validator: (@Sendable (Double) -> Bool)? = { $0 >= 0 }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitEnergy> {
        LocalizedMeasurement(binding, definition: UnitDefinition.calorie)
    }
}

/// Calorie adjustment field definition
struct CalorieAdjustmentFieldDefinition: FieldDefinition {
    typealias Unit = UnitEnergy

    let title: String.LocalizationValue = "Adjustment"
    let icon = Image(systemName: "plusminus.circle")
        .symbolRenderingMode(.hierarchical)
    let tint = Color.indigo
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    let validator: (@Sendable (Double) -> Bool)? = { _ in true }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitEnergy> {
        LocalizedMeasurement(binding, definition: UnitDefinition.calorie)
    }
}

/// Calorie maintenance field definition
struct MaintenanceFieldDefinition: FieldDefinition {
    typealias Unit = UnitEnergy

    let title: String.LocalizationValue = "Maintenance"
    let icon = Image.maintenance
    let tint = Color.calories
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    let validator: (@Sendable (Double) -> Bool)? = { _ in true }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitEnergy> {
        LocalizedMeasurement(binding, definition: UnitDefinition.calorie)
    }
}

/// Weekly calorie maintenance field definition
struct WeeklyMaintenanceFieldDefinition: FieldDefinition {
    typealias Unit = UnitEnergy

    let title: String.LocalizationValue = "Weekly Maintenance"
    let icon = Image.maintenance
    let tint = Color.calories
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    let validator: (@Sendable (Double) -> Bool)? = { _ in true }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitEnergy> {
        LocalizedMeasurement(binding, definition: UnitDefinition.calorie)
    }
}

/// Weekly calorie adjustment field definition
struct WeeklyCalorieAdjustmentFieldDefinition: FieldDefinition {
    typealias Unit = UnitEnergy

    let title: String.LocalizationValue = "Weekly Adjustment"
    let icon = Image(systemName: "plusminus.circle")
        .symbolRenderingMode(.hierarchical)
    let tint = Color.indigo
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    let validator: (@Sendable (Double) -> Bool)? = { _ in true }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitEnergy> {
        LocalizedMeasurement(binding, definition: UnitDefinition.calorie)
    }
}

@MainActor
let calorieRecordDefinition = RecordDefinition(
    title: "Calories", icon: .calories, color: .calories
) { calorie in
    CalorieFields(calorie: calorie)
} row: { (calorie: DietaryCalorie) in
    DetailedRow(image: nil, tint: nil) {
        ValueView(
            measurement: .init(
                baseValue: .constant(calorie.calories),
                definition: UnitDefinition.calorie
            ),
            icon: nil, tint: nil,
            format: CalorieFieldDefinition().formatter
        )
    } subtitle: {
    } details: {
        HStack(spacing: 6) {
            MacroValueView(
                value: calorie.macros?.protein,
                field: ProteinFieldDefinition()
            )
            MacroValueView(
                value: calorie.macros?.carbs,
                field: CarbsFieldDefinition()
            )
            MacroValueView(
                value: calorie.macros?.fat,
                field: FatFieldDefinition()
            )

            AlcoholValueView(
                value: calorie.alcohol,
                field: AlcoholFieldDefinition()
            )
        }
    }
}

struct CalorieFields: View {
    @Bindable var calorie: DietaryCalorie

    init(calorie: Binding<DietaryCalorie>) {
        self.calorie = calorie.wrappedValue
    }

    var body: some View {
        let macros = $calorie.macros.defaulted(to: .init())

        // Calories field
        RecordRow(
            field: CalorieFieldDefinition().withComputed {
                calorie.calculatedCalories()
            },
            value: $calorie.calories.optional(0),
            isInternal: calorie.source == .app,
            showPicker: true
        )

        Section {
            // Protein field
            RecordRow(
                field: ProteinFieldDefinition().withComputed {
                    calorie.calculatedProtein()
                },
                value: macros.protein,
                isInternal: calorie.source == .app
            )

            // Carbs field
            RecordRow(
                field: CarbsFieldDefinition().withComputed {
                    calorie.calculatedCarbs()
                },
                value: macros.carbs,
                isInternal: calorie.source == .app
            )

            // Fat field
            RecordRow(
                field: FatFieldDefinition().withComputed {
                    calorie.calculatedFat()
                },
                value: macros.fat,
                isInternal: calorie.source == .app
            )
        }

        // Alcohol field
        RecordRow(
            field: AlcoholFieldDefinition().withComputed {
                calorie.calculatedAlcohol()
            },
            value: $calorie.alcohol,
            isInternal: calorie.source == .app,
            showPicker: true
        )
    }
}

// MARK: - Form Wrapper

struct CalorieFormView: View {
    let formType: RecordFormType
    let dataModel: HealthDataModel
    @State private var record: DietaryCalorie

    init(formType: RecordFormType, initialRecord: DietaryCalorie, dataModel: HealthDataModel) {
        self.formType = formType
        self.dataModel = dataModel
        self._record = State(initialValue: initialRecord)
    }

    var body: some View {
        RecordForm(
            title: "Calories",
            formType: formType,
            saveFunc: { (record: DietaryCalorie) in
                let query: any HealthQuery<DietaryCalorie> = dataModel.query()
                try await query.save(record, store: HealthKitService.shared)
            },
            deleteFunc: { (record: DietaryCalorie) in
                let query: any HealthQuery<DietaryCalorie> = dataModel.query()
                try await query.delete(record, store: HealthKitService.shared)
            },
            record: $record
        ) { binding in
            CalorieFields(calorie: binding)
        }
    }
}
