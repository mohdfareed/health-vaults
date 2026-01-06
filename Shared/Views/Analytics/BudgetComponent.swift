import Charts
import SwiftData
import SwiftUI

// MARK: - Budget Component
// ============================================================================

/// Reusable budget component for dashboard and home-screen widgets.
///
/// Uses the centralized `AppHealthKitObserver` + `HealthDataNotifications` pattern
/// for reactive updates. Widgets should pass preloaded data to avoid HealthKit calls.
public struct BudgetComponent: View {
    @State private var dataService: BudgetDataService?
    private let preloadedBudgetService: BudgetService?
    private let logger = AppLogger.new(for: BudgetComponent.self)

    public init(
        adjustment: Double? = nil,
        date: Date = Date(),
        preloadedBudgetService: BudgetService? = nil
    ) {
        self.preloadedBudgetService = preloadedBudgetService

        // Only create data service if no preloaded data is provided
        if preloadedBudgetService == nil {
            self._dataService = State(
                initialValue: BudgetDataService(
                    adjustment: adjustment,
                    date: date
                ))
        } else {
            self._dataService = State(initialValue: nil)
        }
    }

    // Computed property to get the current budget service
    private var currentBudgetService: BudgetService? {
        preloadedBudgetService ?? dataService?.budgetService
    }

    private var isLoading: Bool {
        if preloadedBudgetService != nil {
            return false  // Never loading when using preloaded data
        }
        return dataService?.isLoading ?? true
    }

    public var body: some View {
        Group {
            if let budget = currentBudgetService {
                BudgetDataLayout(budget: budget)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .animation(.default, value: currentBudgetService != nil)
        .animation(.default, value: isLoading)
        .task {
            // Load data on initial appearance (widgets provide preloaded data)
            if preloadedBudgetService == nil {
                await dataService?.refresh()
            }
        }
        .refreshOnHealthDataChange(for: [.dietaryCalories, .bodyMass]) {
            // Auto-refresh when AppHealthKitObserver detects changes
            // Only refresh if using data service (not preloaded widget data)
            if preloadedBudgetService == nil {
                await dataService?.refresh()
            }
        }
    }
}

// MARK: - Content Views
// ============================================================================

/// Shared data layout for both dashboard and widget
private struct BudgetDataLayout: View {
    let budget: BudgetService
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallBudgetLayout(budget: budget)
        case .systemMedium:
            MediumBudgetLayout(budget: budget).padding()
        default:
            // Default to medium layout for dashboard and other contexts
            MediumBudgetLayout(budget: budget)
        }
    }
}

/// Medium widget and dashboard layout with progress ring
private struct MediumBudgetLayout: View {
    let budget: BudgetService
    @Environment(\.widgetFamily) private var widgetFamily

    /// Detect if running in widget context based on environment.
    private var isWidget: Bool {
        widgetFamily != .systemLarge  // .systemLarge is default when not in widget
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                CalorieContent(data: budget)
                BudgetContent(data: budget, isWidget: isWidget)
                CreditContent(data: budget)
            }
            Spacer()
            ProgressRing(
                value: budget.baseBudget,
                progress: budget.calories.currentIntake ?? 0,
                threshold: budget.budget,
                color: .calories,
                thresholdColor: budget.credit ?? 0 >= 0 ? .green : .red,
                icon: Image.calories
            )
            .frame(maxWidth: 80)
        }
    }
}

/// Small widget layout without progress ring
private struct SmallBudgetLayout: View {
    let budget: BudgetService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                ProgressRing(
                    value: budget.baseBudget,
                    progress: budget.calories.currentIntake ?? 0,
                    threshold: budget.budget,
                    color: .calories,
                    thresholdColor: budget.credit ?? 0 >= 0 ? .green : .red,
                    icon: Image.calories
                )
                .frame(width: 50, height: 50)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(budget.remaining, format: CalorieFieldDefinition().formatter)
                    .fontWeight(.bold)
                    .font(.title)
                    .foregroundColor(budget.remaining >= 0 ? .primary : .red)
                    .contentTransition(.numericText(value: budget.remaining))
                CreditContent(data: budget)
            }
        }
        .padding(4)
    }
}

@MainActor @ViewBuilder
private func CalorieContent(data: BudgetService) -> some View {
    let formatter = CalorieFieldDefinition().formatter
    HStack(alignment: .firstTextBaseline, spacing: 0) {
        ValueView(
            measurement: .init(
                baseValue: .constant(data.remaining),
                definition: UnitDefinition<UnitEnergy>.calorie
            ),
            icon: nil, tint: nil, format: formatter
        )
        .fontWeight(.bold)
        .font(.title)
        .foregroundColor(data.remaining >= 0 ? .primary : .red)
        .contentTransition(.numericText(value: data.remaining))
    }
}

@MainActor @ViewBuilder
private func BudgetContent(data: BudgetService, isWidget: Bool = false) -> some View {
    let formatter = CalorieFieldDefinition().formatter
    HStack(alignment: .firstTextBaseline, spacing: 0) {
        // Disable animation in widget context to avoid battery drain and visual artifacts
        if isWidget {
            Image.maintenance
                .foregroundColor(.calories)
                .font(.subheadline)
                .frame(width: 18, height: 18, alignment: .center)
                .padding(.trailing, 8)
        } else {
            Image.maintenance
                .symbolEffect(
                    .rotate.byLayer,
                    options: data.isValid && data.weight.isValid
                        ? .nonRepeating
                        : .repeat(.periodic(delay: 5))
                )
                .foregroundColor(.calories)
                .font(.subheadline)
                .frame(width: 18, height: 18, alignment: .center)
                .padding(.trailing, 8)
        }

        Text(data.calories.currentIntake ?? 0, format: formatter)
            .fontWeight(.bold)
            .font(.headline)
            .foregroundColor(.secondary)
            .contentTransition(
                .numericText(
                    value: data.calories.currentIntake ?? 0)
            )

        Text("/")
            .font(.headline)
            .foregroundColor(.secondary)

        ValueView(
            measurement: .init(
                baseValue: .constant(data.budget),
                definition: UnitDefinition<UnitEnergy>.calorie
            ),
            icon: nil, tint: nil, format: formatter
        )
        .fontWeight(.bold)
        .font(.headline)
        .foregroundColor(.secondary)
        .contentTransition(.numericText(value: data.budget))
    }
}

@MainActor @ViewBuilder
private func CreditContent(data: BudgetService) -> some View {
    let formatter = CalorieFieldDefinition().formatter
    HStack(alignment: .firstTextBaseline, spacing: 0) {
        Image.credit
            .foregroundColor(data.credit ?? 0 >= 0 ? .green : .red)
            .font(.headline)
            .frame(width: 18, height: 18, alignment: .center)
            .padding(.trailing, 8)

        if let credit = data.credit {
            ValueView(
                measurement: .init(
                    baseValue: .constant(credit),
                    definition: UnitDefinition<UnitEnergy>.calorie
                ),
                icon: nil, tint: nil, format: formatter
            )
            .fontWeight(.bold)
            .font(.headline)
            .foregroundColor(.secondary)
            .contentTransition(.numericText(value: credit))
        } else {
            Text("No data available")
                .fontWeight(.bold)
                .foregroundColor(.secondary)
        }
    }
}
