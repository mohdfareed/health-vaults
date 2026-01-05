import SwiftData
import SwiftUI

public enum RecordFormType {
    case view, create, edit
}

struct RecordForm<R: HealthData & Sendable, Content: View>: View {
    @Environment(\.healthKit) private var healthKit
    @Environment(\.dismiss) private var dismiss

    @State private var showConfirmation = false
    @State private var isLoading = false

    let title: String.LocalizationValue
    let formType: RecordFormType

    let saveFunc: (R) async throws -> Void
    let deleteFunc: (R) async throws -> Void

    @Binding var record: R
    @ViewBuilder let content: (Binding<R>) -> Content

    var body: some View {
        Form {
            content($record)

            Section {
                DatePicker(
                    selection: $record.date,
                    displayedComponents: [.date, .hourAndMinute]
                ) {
                    Label("Date", systemImage: "calendar")
                }
                .disabled(formType == .view)
            }

            if formType != .create {
                LabeledContent {
                    Text(record.source.localized)
                        .foregroundStyle(.tertiary)
                } label: {
                    Label {
                        Text("Source")
                    } icon: {
                        record.source.icon
                            .foregroundStyle(record.source.color)
                    }
                }
            }
        }
        .navigationTitle(String(localized: title))
        .scrollDismissesKeyboard(.immediately)

        .toolbar {
            if formType == .view {  // HealthKit samples
                viewButtons()
            } else if formType == .edit {  // App samples
                editButtons()
            } else {  // New (app) samples
                createButtons()
            }
        }.toolbarTitleDisplayMode(.inline)
    }

    @ToolbarContentBuilder
    private func viewButtons() -> some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(role: .close) {
                dismiss()
            } label: {
                Label("Done", systemImage: "checkmark")
            }
        }
    }

    @ToolbarContentBuilder
    private func editButtons() -> some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(role: .destructive) {
                showConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }

            .confirmationDialog(
                "Delete \(String(localized: title)) Record",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    let wrapper = { await delete(record) }
                    Task {
                        await wrapper()
                    }
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            LoadingButton(role: .confirm) {
                await save(record)
                dismiss()
            } label: {
                Label("Save", systemImage: "checkmark")
            }
        }
    }

    @ToolbarContentBuilder
    private func createButtons() -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .cancel) {
                dismiss()
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            LoadingButton(role: .confirm) {
                await save(record)
                dismiss()
            } label: {
                Label("Add", systemImage: "plus")
            }
        }
    }

    private func save(_ record: R) async {
        do {
            try await saveFunc(record)
        } catch {
            AppLogger.new(for: record).error(
                "Failed to save record: \(error)"
            )
        }
    }

    private func delete(_ record: R) async {
        do {
            try await deleteFunc(record)
        } catch {
            AppLogger.new(for: record).error(
                "Failed to delete record: \(error)"
            )
        }
    }
}

struct LoadingButton<Label: View>: View {
    @State var isLoading: Bool = false

    let role: ButtonRole?

    let action: () async -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        if isLoading {
            ProgressView()
        } else {
            Button(role: role) {
                withAnimation(.default) {
                    isLoading = true
                }

                let buttonAction = {
                    await action()
                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                    await MainActor.run {
                        withAnimation(.default) {
                            isLoading = false
                        }
                    }
                }

                Task { await buttonAction() }
            } label: {
                label()
            }
        }
    }
}
