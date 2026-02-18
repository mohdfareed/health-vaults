import SwiftUI

extension HealthDataModel {
    @MainActor public var definition: RecordDefinition {
        switch self {
        case .weight:
            return weightRecordDefinition
        case .calorie:
            return calorieRecordDefinition
        case .bodyFat:
            return bodyFatRecordDefinition
        }
    }

    @MainActor @ViewBuilder public var recordList: some View {
        switch self {
        case .weight:
            RecordList(.weight, for: Weight.self)
        case .calorie:
            RecordList(.calorie, for: DietaryCalorie.self)
        case .bodyFat:
            RecordList(.bodyFat, for: BodyFatPercentage.self)
        }
    }
}

// MARK: Field Definition Protocol
// ============================================================================

/// Protocol for type-safe field definitions that know their own unit type
protocol FieldDefinition {
    associatedtype Unit: Dimension

    var title: String.LocalizationValue { get }
    var icon: Image { get }
    var tint: Color { get }
    var formatter: FloatingPointFormatStyle<Double> { get }
    var validator: (@Sendable (Double) -> Bool)? { get }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<Unit>
}

// MARK: Computed Field Extension
// ============================================================================

/// Protocol for field definitions that can provide computed values
protocol ComputedField {
    var compute: (() -> Double?)? { get }
}

extension FieldDefinition {
    func withComputed(_ computeFunc: @escaping () -> Double?) -> ComputedFieldDefinition<Self> {
        ComputedFieldDefinition(base: self, compute: computeFunc)
    }
}

/// Wrapper for field definitions with computed values
struct ComputedFieldDefinition<Base: FieldDefinition>: FieldDefinition, ComputedField {
    typealias Unit = Base.Unit

    let base: Base
    let compute: (() -> Double?)?

    init(base: Base, compute: @escaping () -> Double?) {
        self.base = base
        self.compute = compute
    }

    var title: String.LocalizationValue { base.title }
    var icon: Image { base.icon }
    var tint: Color { base.tint }
    var formatter: FloatingPointFormatStyle<Double> { base.formatter }
    var validator: (@Sendable (Double) -> Bool)? { base.validator }

    @MainActor
    func measurement(_ binding: Binding<Double?>) -> LocalizedMeasurement<Unit> {
        base.measurement(binding)
    }
}

// MARK: Health Record Definition
// ============================================================================

/// Definition of UI-specific behavior for health data types.
/// Each health data type creates this to define its visual appearance,
/// form configuration, and display behavior.
@MainActor
public struct RecordDefinition {
    public let title: String.LocalizationValue
    public let icon: Image
    public let color: Color

    let formView: (Binding<any HealthData>) -> AnyView
    let rowView: (any HealthData) -> AnyView
    let aggregateView: (Double) -> AnyView

    init<Data: HealthData, FormContent: View, RowContent: View, AggregateContent: View>(
        title: String.LocalizationValue, icon: Image, color: Color,
        @ViewBuilder form: @escaping (Binding<Data>) -> FormContent,
        @ViewBuilder row: @escaping (Data) -> RowContent,
        @ViewBuilder aggregate: @escaping (Double) -> AggregateContent
    ) {
        self.title = title
        self.icon = icon
        self.color = color

        self.formView = { binding in
            let typedBinding = Binding<Data>(
                get: { binding.wrappedValue as! Data },
                set: { binding.wrappedValue = $0 }
            )
            return AnyView(form(typedBinding))
        }
        self.rowView = { record in AnyView(row(record as! Data)) }
        self.aggregateView = { value in AnyView(aggregate(value)) }
    }
}

// MARK: Form Creation
// ============================================================================

extension HealthDataModel {
    /// Creates the appropriate form for this data model type
    @MainActor @ViewBuilder
    public func createForm(
        formType: RecordFormType, record: (any HealthData)? = nil,
        defaultDate: Date? = nil
    ) -> some View {
        switch self {
        case .calorie:
            let initial = (record as? DietaryCalorie) ?? DietaryCalorie()
            let _ = defaultDate.map { initial.date = $0 }
            CalorieFormView(
                formType: formType,
                initialRecord: initial,
                dataModel: self
            )
        case .weight:
            let initial = (record as? Weight) ?? Weight()
            let _ = defaultDate.map { initial.date = $0 }
            WeightFormView(
                formType: formType,
                initialRecord: initial,
                dataModel: self
            )
        case .bodyFat:
            let initial = (record as? BodyFatPercentage) ?? BodyFatPercentage()
            let _ = defaultDate.map { initial.date = $0 }
            BodyFatFormView(
                formType: formType,
                initialRecord: initial,
                dataModel: self
            )
        }
    }
}
