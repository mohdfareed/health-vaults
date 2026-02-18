import HealthVaultsShared
import SwiftData
import SwiftUI

struct HealthDataView: View {
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                Section("Records") {
                    ForEach(HealthDataModel.allCases, id: \.self) { model in
                        NavigationLink(value: model) {
                            Label {
                                Text(String(localized: model.definition.title))
                            } icon: {
                                model.definition.icon
                                    .foregroundStyle(model.definition.color)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Health Data")
            .navigationDestination(for: HealthDataModel.self) {
                $0.recordList
            }
        }
    }
}
