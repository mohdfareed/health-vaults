import Charts
import SwiftData
import SwiftUI

// MARK: - Macros Component
// ============================================================================

/// Reusable macros component for widgets.
public struct MacrosComponent: View {
    @State private var budgetDataService: BudgetDataService?
    @State private var macrosDataService: MacrosDataService?

    private let preloadedMacrosService: MacrosAnalyticsService?
    private let macroAdjustments: CalorieMacros?
    private let selectedMacro: MacroType?
    private let date: Date
    private let logger = AppLogger.new(for: MacrosComponent.self)

    public init(
        adjustment: Double? = nil,
        macroAdjustments: CalorieMacros? = nil,
        selectedMacro: MacroType? = nil,
        date: Date = Date(),
        preloadedMacrosService: MacrosAnalyticsService? = nil
    ) {
        self.preloadedMacrosService = preloadedMacrosService
        self.macroAdjustments = macroAdjustments
        self.selectedMacro = selectedMacro
        self.date = date

        // Only create data services if no preloaded data is provided
        if preloadedMacrosService == nil {
            self._budgetDataService = State(
                initialValue: BudgetDataService(
                    adjustment: adjustment,
                    date: date
                ))

            self._macrosDataService = State(
                initialValue: MacrosDataService(
                    adjustments: macroAdjustments,
                    date: date
                ))
        } else {
            self._budgetDataService = State(initialValue: nil)
            self._macrosDataService = State(initialValue: nil)
        }
    }

    // Computed property to get the current macros service
    private var currentMacrosService: MacrosAnalyticsService? {
        preloadedMacrosService ?? macrosDataService?.macrosService
    }

    private var isLoading: Bool {
        if preloadedMacrosService != nil {
            return false  // Never loading when using preloaded data
        }
        return macrosDataService?.isLoading ?? budgetDataService?.isLoading ?? true
    }

    public var body: some View {
        Group {
            if let macros = currentMacrosService {
                MacrosDataLayout(macros: macros, selectedMacro: selectedMacro)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .animation(.default, value: currentMacrosService != nil)
        .animation(.default, value: isLoading)

        .refreshOnHealthDataChange(
            for: [.dietaryCalories, .bodyMass, .protein, .carbs, .fat]
        ) {
            if preloadedMacrosService == nil {
                await refresh()
            }
        }
        .task {
            // Only refresh if using data services (not preloaded data)
            if preloadedMacrosService == nil {
                await refresh()
            }
        }
    }

    /// Refresh data for in-app usage (not widget mode)
    private func refresh() async {
        guard preloadedMacrosService == nil else {
            return
        }

        // Refresh budget data first
        await budgetDataService?.refresh()

        // Once budget is loaded, recreate macros service with budget dependency
        if let budgetService = budgetDataService?.budgetService {
            let newMacrosDataService = MacrosDataService(
                budgetService: budgetService,
                adjustments: macroAdjustments,
                date: date
            )
            macrosDataService = newMacrosDataService

            // Now refresh macros with budget context
            await macrosDataService?.refresh()
        }
    }
}

// MARK: - Content Views
// ============================================================================

/// Shared data layout for both dashboard and widget
private struct MacrosDataLayout: View {
    let macros: MacrosAnalyticsService
    let selectedMacro: MacroType?
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallMacrosLayout(macros: macros, selectedMacro: selectedMacro ?? .protein)
        case .systemMedium:
            MediumMacrosLayout(macros: macros).padding()
        default:
            // Default to medium layout for dashboard and other contexts
            MediumMacrosLayout(macros: macros)
        }
    }
}

/// Medium widget and dashboard layout with all macros
private struct MediumMacrosLayout: View {
    let macros: MacrosAnalyticsService

    var body: some View {
        HStack {
            MacroBudgetContent(macros: macros, ring: .protein)
            Spacer()
            Divider()
            Spacer()
            MacroBudgetContent(macros: macros, ring: .carbs)
            Spacer()
            Divider()
            Spacer()
            MacroBudgetContent(macros: macros, ring: .fat)
        }
    }
}

/// Small widget layout showing single selected macro
private struct SmallMacrosLayout: View {
    let macros: MacrosAnalyticsService
    let selectedMacro: MacroType

    var body: some View {
        MacroBudgetContent(macros: macros, ring: selectedMacro)
    }
}

// MARK: - Macro Data Content Views
// ============================================================================

@MainActor
private struct MacroBudgetContent: View {
    let macros: MacrosAnalyticsService
    let ring: MacrosAnalyticsService.MacroRing
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        let formatter = ProteinFieldDefinition().formatter

        switch widgetFamily {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    progressRing
                        .frame(width: 50, height: 50)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(remaining ?? 0, format: CalorieFieldDefinition().formatter)
                        .fontWeight(.bold)
                        .font(.title)
                        .foregroundColor(remaining ?? 0 >= 0 ? .primary : .red)
                        .contentTransition(.numericText(value: remaining ?? 0))
                    intakeBudgetContent(format: formatter)
                }
            }
            .padding(4)
        case .systemMedium:
            VStack(alignment: .center, spacing: 0) {
                remainingContent(format: formatter)
                intakeBudgetContent(format: formatter).padding(.bottom, 8)
                progressRing
            }
        default:
            // Default to medium layout for dashboard and other contexts
            VStack(alignment: .center, spacing: 0) {
                remainingContent(format: formatter)
                intakeBudgetContent(format: formatter).padding(.bottom, 8)
                progressRing
            }
        }
    }

    // MARK: - Shared Content Components

    @ViewBuilder
    private func remainingContent(format: FloatingPointFormatStyle<Double>)
        -> some View
    {
        ValueView(
            measurement: .init(
                baseValue: .constant(remaining),
                definition: UnitDefinition<UnitMass>.macro
            ),
            icon: nil, tint: nil, format: format
        )
        .fontWeight(.bold)
        .font(widgetFamily == .systemSmall ? .title : .title2)
        .foregroundColor(remaining ?? 0 >= 0 ? .primary : .red)
        .contentTransition(.numericText(value: remaining ?? 0))
    }

    @ViewBuilder
    private func intakeBudgetContent(
        format: FloatingPointFormatStyle<Double>
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if widgetFamily == .systemSmall {
                icon?
                    .foregroundColor(color)
                    .font(.subheadline)
                    .frame(width: 18, height: 18, alignment: .center)
                    .padding(.trailing, 8)
            }

            Text(intake ?? 0, format: format)
                .fontWeight(.bold)
                .font(widgetFamily == .systemSmall ? .headline : .subheadline)
                .foregroundColor(.secondary)
                .contentTransition(.numericText(value: intake ?? 0))

            Text("/")
                .font(widgetFamily == .systemSmall ? .headline : .subheadline)
                .foregroundColor(.secondary)

            ValueView(
                measurement: .init(
                    baseValue: .constant(budget),
                    definition: UnitDefinition<UnitMass>.macro
                ),
                icon: nil, tint: nil, format: format
            )
            .fontWeight(.bold)
            .font(widgetFamily == .systemSmall ? .headline : .subheadline)
            .foregroundColor(.secondary)
            .contentTransition(.numericText(value: budget ?? 0))
        }
    }

    @ViewBuilder
    private var progressRing: some View {
        ProgressRing(
            value: budget ?? 0,
            progress: intake ?? 0,
            threshold: budget ?? 0,
            color: color,
            thresholdColor: remaining ?? 0 >= 0 ? .green : .red,
            icon: icon
        )
        .frame(maxWidth: 60)
    }

    // MARK: - Data Accessors

    private var intake: Double? {
        switch ring {
        case .protein: return macros.protein.currentIntake
        case .carbs: return macros.carbs.currentIntake
        case .fat: return macros.fat.currentIntake
        }
    }

    private var budget: Double? {
        switch ring {
        case .protein: return macros.budgets?.protein
        case .carbs: return macros.budgets?.carbs
        case .fat: return macros.budgets?.fat
        }
    }

    private var remaining: Double? {
        switch ring {
        case .protein: return macros.remaining?.protein
        case .carbs: return macros.remaining?.carbs
        case .fat: return macros.remaining?.fat
        }
    }

    private var icon: Image? {
        switch ring {
        case .protein: return .protein
        case .carbs: return .carbs
        case .fat: return .fat
        }
    }

    private var color: Color {
        switch ring {
        case .protein: return .protein
        case .carbs: return .carbs
        case .fat: return .fat
        }
    }
}
