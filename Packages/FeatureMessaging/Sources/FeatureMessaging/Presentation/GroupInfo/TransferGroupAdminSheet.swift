import SwiftUI
import Common
import DesignSystem
import Localization

struct TransferGroupAdminSheet: View {
    let groupId: UUID
    let currentUserId: UUID
    let fetchMembers: (UUID) async throws -> [GroupChatMember]
    let transferAdmin: (UUID, UUID) async throws -> Void
    let onTransferred: () -> Void

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var members: [GroupChatMember] = []
    @State private var loadState: LoadingState<[GroupChatMember]> = .idle
    @State private var selectedMemberId: UUID?
    @State private var isTransferring = false
    @State private var errorMessage: String?

    private var eligibleMembers: [GroupChatMember] {
        members.filter { member in
            !member.isOwner && member.userId != currentUserId
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch loadState {
                case .idle, .loading:
                    LoadingView(message: languageService.text(.messagingGroupMembersLoading))
                case .failed(let message):
                    ErrorView(message: message) {
                        Task { await loadMembers() }
                    }
                case .loaded:
                    if eligibleMembers.isEmpty {
                        EmptyStateView(
                            icon: "person.3",
                            title: languageService.text(.friendsTransferNoMembersTitle),
                            message: languageService.text(.friendsTransferNoMembersMessage)
                        )
                    } else {
                        List(eligibleMembers) { member in
                            Button {
                                selectedMemberId = member.userId
                            } label: {
                                HStack {
                                    AvatarView(
                                        imageURL: member.avatarURL,
                                        name: member.displayName,
                                        size: .medium
                                    )
                                    VStack(alignment: .leading) {
                                        Text(member.displayName)
                                            .font(SplickTheme.Typography.headline)
                                        Text("@\(member.username)")
                                            .font(SplickTheme.Typography.caption)
                                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                                    }
                                    Spacer()
                                    if selectedMemberId == member.userId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle(languageService.text(.friendsTransferTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.friendsTransferAction)) {
                        Task { await transfer() }
                    }
                    .disabled(selectedMemberId == nil || isTransferring)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .padding()
                }
            }
            .task { await loadMembers() }
        }
    }

    private func loadMembers() async {
        loadState = .loading
        errorMessage = nil
        do {
            let loaded = try await fetchMembers(groupId)
            members = loaded
            loadState = .loaded(loaded)
        } catch {
            loadState = .failed(languageService.localizedMessage(for: error))
        }
    }

    private func transfer() async {
        guard let newAdminId = selectedMemberId else { return }
        isTransferring = true
        errorMessage = nil
        defer { isTransferring = false }
        do {
            try await transferAdmin(groupId, newAdminId)
            onTransferred()
            dismiss()
        } catch {
            errorMessage = languageService.localizedMessage(for: error)
        }
    }
}
