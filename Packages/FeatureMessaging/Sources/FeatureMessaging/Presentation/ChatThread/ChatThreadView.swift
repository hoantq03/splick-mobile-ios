import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain
import Storage

public struct ChatThreadView: View {
    @ObservedObject private var viewModel: ChatThreadViewModel
    @ObservedObject private var relationshipViewModel: ChatPeerRelationshipViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.openUserProfile) private var openUserProfile
    @Environment(\.currentUserSummary) private var currentUserSummary
    @FocusState private var isInputFocused: Bool
    @State private var inputText: String = ""

    private let currentUserId: UUID
    private let peer: ConversationPeer?
    private let navigationTitle: String
    private let conversation: Conversation?
    private let repository: MessagingRepositoryProtocol?

    @State private var groupConversation: Conversation?
    @State private var activeGroupSheet: GroupChatSheet?
    @State private var confirmLeaveGroup = false

    @Environment(\.chatGroupManagementActions) private var groupManagementActions
    @Environment(\.dismiss) private var dismiss

    public init(
        viewModel: ChatThreadViewModel,
        relationshipViewModel: ChatPeerRelationshipViewModel,
        currentUserId: UUID,
        peer: ConversationPeer? = nil,
        navigationTitle: String = "",
        conversation: Conversation? = nil,
        repository: MessagingRepositoryProtocol? = nil
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._relationshipViewModel = ObservedObject(wrappedValue: relationshipViewModel)
        self.currentUserId = currentUserId
        self.peer = peer
        self.navigationTitle = navigationTitle
        self.conversation = conversation
        self.repository = repository
    }

    public var body: some View {
        VStack(spacing: 0) {
            if relationshipViewModel.showsAddFriendBanner {
                ChatAddFriendBanner(
                    message: addFriendBannerMessage,
                    actionTitle: addFriendBannerActionTitle,
                    actionSystemImage: addFriendBannerActionSystemImage,
                    isProcessing: relationshipViewModel.isProcessing
                ) {
                    Task { await performAddFriendBannerAction() }
                }
            }
            messageArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            bottomBar
                .fixedSize(horizontal: false, vertical: true)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: openChatHeader) {
                    HStack(spacing: SplickTheme.Spacing.xs) {
                        AvatarView(
                            imageURL: (displayConversation?.isGroup == true
                                ? displayConversation?.groupAvatarUrl
                                : peer?.avatarUrl)?.flatMap(URL.init(string:)),
                            name: navigationTitle,
                            size: .small
                        )
                        Text(displayConversation?.displayTitle ?? navigationTitle)
                            .font(SplickTheme.Typography.headline)
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(navigationTitle)
                .disabled(!canOpenChatHeader)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if displayConversation?.isGroup == true, repository != nil {
                    groupChatOptionsMenu
                } else if relationshipViewModel.isActive, !relationshipViewModel.isBlocked {
                    directChatOptionsMenu
                }
            }
        }
        .sheet(item: $activeGroupSheet) { sheet in
            if let displayConversation, let repository {
                switch sheet {
                case .rename:
                    GroupRenameSheet(groupName: displayConversation.groupName ?? "") { name in
                        let updated = try await repository.renameGroup(groupId: displayConversation.id, name: name)
                        applyConversationUpdate(updated)
                    }
                case .avatar:
                    GroupAvatarSheet(
                        groupName: displayConversation.displayTitle,
                        currentAvatarURL: displayConversation.groupAvatarUrl.flatMap(URL.init(string:))
                    ) { imageData in
                        let avatarURL = try await groupManagementActions.updateGroupAvatar(
                            displayConversation.id,
                            imageData
                        )
                        applyConversationUpdate(
                            displayConversation.updating(groupAvatarUrl: avatarURL)
                        )
                        return avatarURL
                    }
                case .members:
                    GroupMembersSheet(
                        groupId: displayConversation.id,
                        currentUserId: currentUserId,
                        fetchMembers: groupManagementActions.fetchMembers,
                        removeMember: { groupId, memberUserId in
                            try await repository.removeGroupMember(
                                groupId: groupId,
                                memberUserId: memberUserId
                            )
                        }
                    )
                }
            }
        }
        .confirmationDialog(
            languageService.text(.messagingLeaveGroupConfirmTitle),
            isPresented: $confirmLeaveGroup,
            titleVisibility: .visible
        ) {
            Button(languageService.text(.messagingLeaveGroup), role: .destructive) {
                Task { await leaveGroup() }
            }
            Button(languageService.text(.commonCancel), role: .cancel) {}
        }
        .confirmationDialog(
            languageService.text(.friendsRemoveFriendConfirmTitle),
            isPresented: $relationshipViewModel.showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button(languageService.text(.friendsRemoveFriendConfirmAction), role: .destructive) {
                Task { await relationshipViewModel.removeFriend() }
            }
        }
        .confirmationDialog(
            languageService.text(.friendsBlockConfirmTitle),
            isPresented: $relationshipViewModel.showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button(languageService.text(.friendsBlockConfirmAction), role: .destructive) {
                Task { await relationshipViewModel.blockUser() }
            }
        }
        .onChange(of: relationshipViewModel.isBlocked) { isBlocked in
            guard isBlocked else { return }
            inputText = ""
            viewModel.attachmentDrafts = []
            viewModel.cancelReply()
            isInputFocused = false
        }
        .onAppear {
            tabBarScrollState?.hide(flushToBottom: true)
            if groupConversation == nil {
                groupConversation = conversation
            }
        }
        .onDisappear { tabBarScrollState?.show() }
        .task {
            async let messages: Void = viewModel.loadIfNeeded()
            async let relationship: Void = relationshipViewModel.loadIfNeeded()
            _ = await (messages, relationship)
        }
    }

    private var displayConversation: Conversation? {
        groupConversation ?? conversation
    }

    private var groupChatOptionsMenu: some View {
        Menu {
            Button {
                activeGroupSheet = .avatar
            } label: {
                Label(
                    languageService.text(.messagingGroupChangeAvatar),
                    systemImage: "photo.circle"
                )
            }

            Button {
                activeGroupSheet = .rename
            } label: {
                Label(
                    languageService.text(.messagingGroupChangeName),
                    systemImage: "pencil"
                )
            }

            Button {
                activeGroupSheet = .members
            } label: {
                Label(
                    languageService.text(.messagingGroupManageMembers),
                    systemImage: "person.2"
                )
            }

            Button(role: .destructive) {
                confirmLeaveGroup = true
            } label: {
                Label(
                    languageService.text(.messagingLeaveGroup),
                    systemImage: "rectangle.portrait.and.arrow.right"
                )
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(languageService.text(.messagingChatMoreAccessibility))
    }

    private enum GroupChatSheet: Identifiable {
        case rename
        case avatar
        case members

        var id: String {
            switch self {
            case .rename: return "rename"
            case .avatar: return "avatar"
            case .members: return "members"
            }
        }
    }

    private func applyConversationUpdate(_ updated: Conversation) {
        groupConversation = updated
    }

    private func leaveGroup() async {
        guard let displayConversation, let repository else { return }
        do {
            try await repository.leaveGroup(groupId: displayConversation.id)
            dismiss()
        } catch {
            // Leave errors surface on next navigation refresh; keep UX simple here.
        }
    }

    private var directChatOptionsMenu: some View {
        Menu {
            if relationshipViewModel.canRemoveFriend {
                Button(role: .destructive) {
                    relationshipViewModel.showRemoveConfirm = true
                } label: {
                    Label(
                        languageService.text(.friendsRemoveFriend),
                        systemImage: "person.badge.minus"
                    )
                }
            }
            Button(role: .destructive) {
                relationshipViewModel.showBlockConfirm = true
            } label: {
                Label(
                    languageService.text(.friendsBlockUser),
                    systemImage: "hand.raised.fill"
                )
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(languageService.text(.messagingChatMoreAccessibility))
        .disabled(relationshipViewModel.isProcessing)
    }

    private var addFriendBannerMessage: String {
        switch relationshipViewModel.status {
        case .requestSent:
            return languageService.text(.messagingChatRequestSentBanner)
        case .requestReceived:
            return languageService.text(.messagingChatRequestReceivedBanner)
        default:
            return languageService.text(.messagingChatNotFriendsBanner)
        }
    }

    private var addFriendBannerActionTitle: String? {
        switch relationshipViewModel.status {
        case .stranger:
            return languageService.text(.feedProfileAddFriend)
        case .requestReceived:
            return languageService.text(.friendsAccept)
        case .requestSent:
            return nil
        default:
            return nil
        }
    }

    private var addFriendBannerActionSystemImage: String? {
        switch relationshipViewModel.status {
        case .stranger:
            return "person.badge.plus"
        case .requestReceived:
            return "checkmark"
        default:
            return nil
        }
    }

    private func performAddFriendBannerAction() async {
        switch relationshipViewModel.status {
        case .stranger:
            await relationshipViewModel.addFriend()
        case .requestReceived:
            await relationshipViewModel.acceptFriendRequest()
        default:
            break
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if !relationshipViewModel.isActive {
            inputBar
        } else if relationshipViewModel.isBlocked {
            blockedFooter
        } else if relationshipViewModel.status == .unknown {
            relationshipStatusPlaceholder
        } else {
            inputBar
        }
    }

    private var relationshipStatusPlaceholder: some View {
        Color.clear
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .background(SplickTheme.Colors.background)
    }

    private var blockedFooter: some View {
        VStack(spacing: SplickTheme.Spacing.xxs) {
            Text(languageService.text(.messagingChatBlockedMessage))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button {
                Task { await relationshipViewModel.unblockUser() }
            } label: {
                Text(languageService.text(.friendsUnblock))
                    .font(SplickTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
            .disabled(relationshipViewModel.isProcessing)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(SplickTheme.Colors.background)
    }

    private var canOpenChatHeader: Bool {
        if displayConversation?.isGroup == true {
            return false
        }
        return peer != nil && openUserProfile != nil
    }

    private func openChatHeader() {
        guard let peer, let openUserProfile else { return }
        let user = UserSummary(
            id: peer.userId,
            username: peer.username,
            displayName: peer.displayTitle,
            avatarURL: peer.avatarUrl.flatMap(URL.init(string:))
        )
        guard user.id != currentUserSummary?.id else { return }
        openUserProfile(user)
    }

    @ViewBuilder
    private var messageArea: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: languageService.text(.messagingChatLoading))
        case .loaded(let messages) where messages.isEmpty:
            EmptyStateView(
                icon: "bubble.left",
                title: languageService.text(.messagingChatEmptyTitle),
                message: languageService.text(.messagingChatEmptyMessage)
            )
        case .loaded(let messages):
            ChatMessageListView(
                viewModel: viewModel,
                messages: messages,
                currentUserId: currentUserId,
                senderDisplayName: senderDisplayName(for:),
                onRequestComposerFocus: { isInputFocused = true }
            )
        case .failed(let error):
            ErrorView(message: error) {
                Task { await viewModel.load() }
            }
        }
    }

    @ViewBuilder
    private var inputBar: some View {
        VStack(spacing: 0) {
            MessageComposerInputBar(
                text: $inputText,
                attachmentDrafts: $viewModel.attachmentDrafts,
                replyDraft: viewModel.replyDraft,
                onCancelReply: { viewModel.cancelReply() },
                placeholder: languageService.text(.messagingInputPlaceholder),
                isSending: viewModel.isSending,
                errorMessage: nil,
                onSend: { text, submissions in
                    inputText = ""
                    Task { await viewModel.send(body: text, submissions: submissions) }
                },
                isFocused: $isInputFocused
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func senderDisplayName(for message: ChatMessage) -> String {
        if message.senderId == currentUserId {
            return languageService.text(.messagingYou)
        }
        if let resolved = resolvedSenderDisplayName(message.senderId, on: message) {
            return resolved
        }
        return languageService.text(.messagingReplyUnknownSender)
    }

    private func resolvedSenderDisplayName(_ senderId: UUID, on message: ChatMessage) -> String? {
        if let peer, peer.userId == senderId {
            return peer.displayTitle
        }
        if let name = trimmedDisplayName(message.senderDisplayName) {
            return name
        }
        for loaded in viewModel.messages {
            if loaded.senderId == senderId,
               let name = trimmedDisplayName(loaded.senderDisplayName) {
                return name
            }
            if let preview = loaded.replyPreview,
               preview.senderId == senderId,
               let name = trimmedDisplayName(preview.senderDisplayName) {
                return name
            }
        }
        return nil
    }

    private func trimmedDisplayName(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
