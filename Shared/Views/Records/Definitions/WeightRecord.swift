import SwiftUI

// MARK: - Field Definitions

struct WeightFieldDefinition: FieldDefinition {
    typealias Unit = UnitMass

    let title: String.LocalizationValue = "Weight"
    let icon = Image.weight
    let tint = Color.weight
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))
    let validator: (@Sendable (Double) -> Bool)? = { $0 > 0 }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitMass> {
        LocalizedMeasurement(binding, definition: UnitDefinition.weight)
    }
}

@MainActor let weightRecordDefinition = RecordDefinition(
    title: "Weight", icon: .weight, color: .weight
) { weight in
    WeightFields(weight: weight)
} row: { (weight: Weight) in
    ValueView(
        measurement: .init(
            baseValue: .constant(weight.weight),
            definition: UnitDefinition.weight
        ),
        icon: nil, tint: nil,
        format: WeightFieldDefinition().formatter
    )
} aggregate: { value in
    ValueView(
        measurement: .init(
            baseValue: .constant(value),
            definition: UnitDefinition.weight
        ),
        icon: nil, tint: nil,
        format: WeightFieldDefinition().formatter
    )
}

struct WeightFields: View {
    @Bindable var weight: Weight

    init(weight: Binding<Weight>) {
        self.weight = weight.wrappedValue
    }

    var body: some View {
        RecordRow(
            field: WeightFieldDefinition(),
            value: $weight.weight.optional(0),
            isInternal: weight.source == .app,
            showPicker: true
        )
    }
}

// MARK: - Form Wrapper

struct WeightFormView: View {
    let formType: RecordFormType
    let dataModel: HealthDataModel
    @State private var record: Weight

    init(formType: RecordFormType, initialRecord: Weight, dataModel: HealthDataModel) {
        self.formType = formType
        self.dataModel = dataModel
        self._record = State(initialValue: initialRecord)
    }

    var body: some View {
        RecordForm(
            title: "Weight",
            formType: formType,
            requiredType: .bodyMass,
            saveFunc: { (record: Weight) in
                let query: any HealthQuery<Weight> = dataModel.query()
                try await query.save(record, store: HealthKitService.shared)
            },
            deleteFunc: { (record: Weight) in
                let query: any HealthQuery<Weight> = dataModel.query()
                try await query.delete(record, store: HealthKitService.shared)
            },
            record: $record
        ) { binding in
            WeightFields(weight: binding)
        }
    }
}
