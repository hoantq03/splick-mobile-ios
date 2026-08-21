import SwiftUI
import AudioToolbox
import DesignSystem
import Localization

struct ChatNotificationSettingsSheet: View {
    let conversation: Conversation
    let onSave: (Bool, String) async throws -> Void

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled: Bool
    @State private var selectedSound: ConversationNotificationSound
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(conversation: Conversation, onSave: @escaping (Bool, String) async throws -> Void) {
        self.conversation = conversation
        self.onSave = onSave
        _notificationsEnabled = State(initialValue: conversation.notificationsEnabled)
        _selectedSound = State(initialValue: ConversationNotificationSound.resolved(conversation.notificationSound))
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

                Section {
                    ForEach(ConversationNotificationSound.allCases, id: \.self) { sound in
                        Button {
                            selectedSound = sound
                            preview(sound)
                        } label: {
                            HStack {
                                Text(soundTitle(sound))
                                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                                Spacer()
                                if selectedSound == sound {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                                }
                            }
                        }
                        .disabled(!notificationsEnabled)
                    }
                } header: {
                    Text(languageService.text(.messagingChatNotificationBell))
                }
                .opacity(notificationsEnabled ? 1 : 0.45)

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(SplickTheme.Colors.error)
                    }
                }
            }
            .navigationTitle(languageService.text(.messagingChatNotificationSounds))
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

    private func soundTitle(_ sound: ConversationNotificationSound) -> String {
        switch sound {
        case .default: return languageService.text(.messagingChatNotificationSoundDefault)
        case .note: return languageService.text(.messagingChatNotificationSoundNote)
        case .chime: return languageService.text(.messagingChatNotificationSoundChime)
        case .pop: return languageService.text(.messagingChatNotificationSoundPop)
        case .silent: return languageService.text(.messagingChatNotificationSoundSilent)
        }
    }

    private func preview(_ sound: ConversationNotificationSound) {
        guard notificationsEnabled, sound != .silent else { return }
        let systemSoundId: SystemSoundID
        switch sound {
        case .default: systemSoundId = 1007
        case .note: systemSoundId = 1013
        case .chime: systemSoundId = 1016
        case .pop: systemSoundId = 1104
        case .silent: return
        }
        AudioServicesPlaySystemSound(systemSoundId)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await onSave(notificationsEnabled, selectedSound.rawValue)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
