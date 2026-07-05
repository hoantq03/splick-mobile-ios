import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct GroupInfoView: View {
    let conversation: Conversation
    let repository: MessagingRepositoryProtocol
    let currentUserId: UUID
    let onUpdated: () async -> Void

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var groupName: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        conversation: Conversation,
        repository: MessagingRepositoryProtocol,
        currentUserId: UUID,
        onUpdated: @escaping () async -> Void
    ) {
        self.conversation = conversation
        self.repository = repository
        self.currentUserId = currentUserId
        self.onUpdated = onUpdated
        _groupName = State(initialValue: conversation.groupName ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(languageService.text(.messagingGroupNamePlaceholder)) {
                    TextField(languageService.text(.messagingGroupNamePlaceholder), text: $groupName)
                }

                if let memberCount = conversation.memberCount {
                    Section {
                        Text("\(memberCount) \(languageService.text(.messagingGroupMembersTitle))")
                    }
                }

                Section {
                    Button(languageService.text(.messagingLeaveGroup), role: .destructive) {
                        Task {
                            do {
                                try await repository.leaveGroup(groupId: conversation.id)
                                await onUpdated()
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(SplickTheme.Colors.error)
                    }
                }
            }
            .navigationTitle(conversation.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonSave)) {
                        Task { await saveName() }
                    }
                    .disabled(isSaving || groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveName() async {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await repository.renameGroup(
                groupId: conversation.id,
                name: groupName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            await onUpdated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
