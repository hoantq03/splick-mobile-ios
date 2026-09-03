import SwiftUI
import DesignSystem
import Localization

struct ChatNotificationSettingsSheet: View {
    let conversation: Conversation
    let onSave: (Bool) async throws -> Void

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(conversation: Conversation, onSave: @escaping (Bool) async throws -> Void) {
        self.conversation = conversation
        self.onSave = onSave
        _notificationsEnabled = State(initialValue: conversation.notificationsEnabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label(
                            languageService.text(.messagingChatNotificationsToggle),
                            systemImage: notificationsEnabled ? "bell.fill" : "bell.slash"
                        )
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(SplickTheme.Colors.error)
                    }
                }
            }
            .navigationTitle(languageService.text(.messagingChatNotificationsToggle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonSave)) {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await onSave(notificationsEnabled)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
