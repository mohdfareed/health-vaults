import HealthVaultsShared
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Combined Goals View
// ============================================================================

struct GoalsView: View {
    private enum GoalsSection: String, CaseIterable, Identifiable {
        case calories = "Calories"
        case macros = "Macros"

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context: ModelContext
    @Query.Singleton var goals: UserGoals
    @State private var selectedSection: GoalsSection = .calories

    init(_ id: UUID) {
        self._goals = .init(id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Goals Section", selection: $selectedSection) {
                        ForEach(GoalsSection.allCases) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                switch selectedSection {
                case .calories:
                    CalorieGoalFields(goals: Bindable(goals))
                case .macros:
                    MacrosGoalFields(goals: Bindable(goals))
                }
            }
            .navigationTitle("Goals")
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: goals) { save() }
            .onChange(of: goals.macros) { save() }
        }
    }

    private func save() {
        do {
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            AppLogger.new(for: GoalsView.self)
                .error("Failed to save model: \(error)")
        }
    }
}

// MARK: - Calorie Goal View
// ============================================================================

struct CalorieGoalView: View {
    @Environment(\.modelContext) private var context: ModelContext
    @Query.Singleton var goals: UserGoals

    init(_ id: UUID) {
        self._goals = .init(id)
    }

    var body: some View {
        Form {
            CalorieGoalFields(goals: Bindable(goals))
        }
        .navigationTitle("Calorie Goals")
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: goals) { save() }
    }

    private func save() {
        do {
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            AppLogger.new(for: CalorieGoalView.self)
                .error("Failed to save model: \(error)")
        }
    }
}

// MARK: - Macros Goal View
// ============================================================================

struct MacrosGoalView: View {
    @Environment(\.modelContext) private var context: ModelContext
    @Query.Singleton var goals: UserGoals

    init(_ id: UUID) {
        self._goals = .init(id)
    }

    var body: some View {
        Form {
            MacrosGoalFields(goals: Bindable(goals))
        }
        .navigationTitle("Macros")
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: goals.macros) { save() }
    }

    private func save() {
        do {
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            AppLogger.new(for: MacrosGoalView.self)
                .error("Failed to save model: \(error)")
        }
    }
}
