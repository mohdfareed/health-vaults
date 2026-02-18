import SwiftUI

// MARK: - Field Definitions

struct BodyFatFieldDefinition: FieldDefinition {
    typealias Unit = UnitMass

    let title: String.LocalizationValue = "Body Fat"
    let icon = Image.bodyFat
    let tint = Color.bodyFat
    let formatter = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
    let validator: (@Sendable (Double) -> Bool)? = { $0 >= 0 && $0 <= 100 }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<UnitMass> {
        LocalizedMeasurement(binding, definition: UnitDefinition.bodyFat)
    }
}

@MainActor let bodyFatRecordDefinition = RecordDefinition(
    title: "Body Fat", icon: .bodyFat, color: .bodyFat
) { bodyFat in
    BodyFatFields(bodyFat: bodyFat)
} row: { (bodyFat: BodyFatPercentage) in
    ValueView(
        measurement: .init(
            baseValue: .constant(bodyFat.percentage),
            definition: UnitDefinition.bodyFat
        ),
        icon: nil, tint: nil,
        format: BodyFatFieldDefinition().formatter
    )
} aggregate: { value in
    ValueView(
        measurement: .init(
            baseValue: .constant(value),
            definition: UnitDefinition.bodyFat
        ),
        icon: nil, tint: nil,
        format: BodyFatFieldDefinition().formatter
    )
}

struct BodyFatFields: View {
    @Bindable var bodyFat: BodyFatPercentage

    init(bodyFat: Binding<BodyFatPercentage>) {
        self.bodyFat = bodyFat.wrappedValue
    }

    var body: some View {
        RecordRow(
            field: BodyFatFieldDefinition(),
            value: $bodyFat.percentage.optional(0),
            isInternal: bodyFat.source == .app
        )
    }
}

// MARK: - Form Wrapper

struct BodyFatFormView: View {
    let formType: RecordFormType
    let dataModel: HealthDataModel
    @State private var record: BodyFatPercentage

    init(
        formType: RecordFormType,
        initialRecord: BodyFatPercentage,
        dataModel: HealthDataModel
    ) {
        self.formType = formType
        self.dataModel = dataModel
        self._record = State(initialValue: initialRecord)
    }

    var body: some View {
        RecordForm(
            title: "Body Fat",
            formType: formType,
            requiredType: .bodyFatPercentage,
            saveFunc: { (record: BodyFatPercentage) in
                let query: any HealthQuery<BodyFatPercentage> = dataModel.query()
                try await query.save(record, store: HealthKitService.shared)
            },
            deleteFunc: { (record: BodyFatPercentage) in
                let query: any HealthQuery<BodyFatPercentage> = dataModel.query()
                try await query.delete(record, store: HealthKitService.shared)
            },
            record: $record
        ) { binding in
            BodyFatFields(bodyFat: binding)
        }
    }
}
