import SwiftUI
import DesignSystem
import Localization

struct GroupRenameSheet: View {
    let groupName: String
    let onSave: (String) async throws -> Void

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(groupName: String, onSave: @escaping (String) async throws -> Void) {
        self.groupName = groupName
        self.onSave = onSave
        _name = State(initialValue: groupName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(languageService.text(.messagingGroupNamePlaceholder), text: $name)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(SplickTheme.Colors.error)
                    }
                }
            }
            .navigationTitle(languageService.text(.messagingGroupChangeName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonSave)) {
                        Task { await save() }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
