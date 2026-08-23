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
    @EnvironmentObject private var presenceStore: PresenceStore
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.openUserProfile) private var openUserProfile
    @Environment(\.currentUserSummary) private var currentUserSummary
    @FocusState private var isInputFocused: Bool
    @State private var inputText: String = ""
    @State private var isSearchingThread = false
    @State private var threadSearchDraft = ""
    @FocusState private var isThreadSearchFocused: Bool

    private let currentUserId: UUID
    private let peer: ConversationPeer?
    private let navigationTitle: String
    private let conversation: Conversation?
    private let repository: MessagingRepositoryProtocol?

    @State private var groupConversation: Conversation?
    @State private var activeGroupSheet: GroupChatSheet?
    @State private var confirmLeaveGroup = false
    @State private var confirmDeleteConversation = false
    @State private var comingSoonFeatureTitle: String?
    @State private var showNotificationSettings = false

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
        ZStack {
            threadContent
                .dismissKeyboardOnTap()
            if isSearchingThread {
                ChatThreadSearchOverlay(
                    viewModel: viewModel,
                    query: $threadSearchDraft,
                    isSearchFocused: $isThreadSearchFocused,
                    onSelectHit: { hit in
                        closeThreadSearch()
                        Task { await viewModel.revealSearchedMessage(id: hit.messageId) }
                    },
                    onClose: closeThreadSearch
                )
                .transition(.opacity)
            }
        }
        .background(SplickTheme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .splickInteractivePopEnabled()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: openChatHeader) {
                    HStack(spacing: SplickTheme.Spacing.xs) {
                        if displayConversation?.isGroup != true, let peer {
                            AvatarWithPresenceView(
                                imageURL: peer.avatarUrl.flatMap(URL.init(string:)),
                                name: navigationTitle,
                                size: .small,
                                userId: peer.userId,
                                showOnlineIndicator: PresenceDisplayPolicy.shouldShowOnlineIndicator(
                                    isOnline: resolvedPresence(for: peer).isOnline
                                )
                            )
                        } else {
                            AvatarView(
                                imageURL: (displayConversation?.isGroup == true
                                    ? displayConversation?.groupAvatarUrl
                                    : peer?.avatarUrl)?.flatMap(URL.init(string:)),
                                name: navigationTitle,
                                size: .small
                            )
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(displayConversation?.displayTitle ?? navigationTitle)
                                .font(SplickTheme.Typography.headline)
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                                .lineLimit(1)
                            if let subtitle = headerPresenceSubtitle {
                                Text(subtitle)
                                    .font(SplickTheme.Typography.caption)
                                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(navigationTitle)
                .disabled(!canOpenChatHeader || isSearchingThread)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !isSearchingThread {
                    if displayConversation?.isGroup == true, repository != nil {
                        groupChatOptionsMenu
                    } else {
                        directChatOptionsMenu
                    }
                }
            }
        }
        .onChange(of: threadSearchDraft) { newValue in
            viewModel.onThreadSearchQueryChanged(newValue)
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
        .sheet(isPresented: $showNotificationSettings) {
            if let displayConversation, let repository {
                ChatNotificationSettingsSheet(conversation: displayConversation) { enabled, sound in
                    let updated = try await repository.updateNotificationSettings(
                        conversationId: displayConversation.id,
                        notificationsEnabled: enabled,
                        notificationSound: sound
                    )
                    applyConversationUpdate(
                        displayConversation.updatingNotificationSettings(
                            enabled: updated.notificationsEnabled,
                            sound: updated.notificationSound
                        )
                    )
                }
                .environmentObject(languageService)
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
            languageService.text(.messagingChatDeleteConversationConfirmTitle),
            isPresented: $confirmDeleteConversation,
            titleVisibility: .visible
        ) {
            Button(languageService.text(.messagingChatDeleteConversation), role: .destructive) {
                Task { await deleteConversation() }
            }
            Button(languageService.text(.commonCancel), role: .cancel) {}
        } message: {
            Text(languageService.text(.messagingChatDeleteConversationConfirmMessage))
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
        .alert(
            comingSoonFeatureTitle ?? languageService.text(.messagingChatMoreAccessibility),
            isPresented: comingSoonPresented
        ) {
            Button(languageService.text(.commonOK), role: .cancel) {
                comingSoonFeatureTitle = nil
            }
        } message: {
            Text(languageService.text(.messagingFilterComingSoon))
        }
        .onChange(of: isInputFocused) { focused in
            guard focused else { return }
            viewModel.pinToLatest()
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
        .onDisappear {
            viewModel.stopLocalTyping()
            tabBarScrollState?.show()
        }
        .onChange(of: inputText) { newValue in
            viewModel.onComposerTextChanged(newValue)
        }
        .task {
            async let messages: Void = viewModel.loadIfNeeded()
            async let relationship: Void = relationshipViewModel.loadIfNeeded()
            _ = await (messages, relationship)
        }
    }

    private var displayConversation: Conversation? {
        groupConversation ?? conversation
    }

    private var threadContent: some View {
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
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomBar
                }
        }
    }

    private func openThreadSearch() {
        isSearchingThread = true
        DispatchQueue.main.async {
            isThreadSearchFocused = true
        }
    }

    private func closeThreadSearch() {
        isThreadSearchFocused = false
        threadSearchDraft = ""
        viewModel.clearThreadSearch()
        isSearchingThread = false
    }

    private var comingSoonPresented: Binding<Bool> {
        Binding(
            get: { comingSoonFeatureTitle != nil },
            set: { isPresented in
                if !isPresented {
                    comingSoonFeatureTitle = nil
                }
            }
        )
    }

    private func comingSoonMenuTitle(_ key: L10nKey) -> String {
        "\(languageService.text(key)) (\(languageService.text(.messagingFilterComingSoon)))"
    }

    private func presentComingSoon(_ key: L10nKey) {
        comingSoonFeatureTitle = languageService.text(key)
    }

    @ViewBuilder
    private var conversationComingSoonActions: some View {
        Button {
            openThreadSearch()
        } label: {
            Label(
                languageService.text(.messagingChatSearchMessages),
                systemImage: "magnifyingglass"
            )
        }

        Button {
            showNotificationSettings = true
        } label: {
            Label(
                languageService.text(.messagingChatNotificationSounds),
                systemImage: (displayConversation?.notificationsEnabled ?? true) ? "bell" : "bell.slash"
            )
        }
        .disabled(repository == nil)
    }

    @ViewBuilder
    private var deleteConversationAction: some View {
        Button(role: .destructive) {
            confirmDeleteConversation = true
        } label: {
            Label(
                languageService.text(.messagingChatDeleteConversation),
                systemImage: "trash"
            )
        }
    }

    private var groupChatOptionsMenu: some View {
        Menu {
            conversationComingSoonActions

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

            deleteConversationAction
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

    private func deleteConversation() async {
        guard let displayConversation, let repository else { return }
        do {
            try await repository.deleteConversation(conversationId: displayConversation.id)
            viewModel.clearCachedThread()
            dismiss()
        } catch {
            // Delete errors surface on next navigation refresh; keep UX simple here.
        }
    }

    private var directChatOptionsMenu: some View {
        Menu {
            conversationComingSoonActions

            if relationshipViewModel.isActive, !relationshipViewModel.isBlocked {
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
            }

            deleteConversationAction
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
            return languageService.text(.messagingChatUndoRequest)
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
        case .requestSent:
            return "arrow.uturn.backward"
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
        case .requestSent:
            await relationshipViewModel.cancelFriendRequest()
        default:
            break
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if relationshipViewModel.isBlocked {
            blockedFooter
        } else {
            // Paint the composer on the first frame; do not wait for peer status.
            inputBar
        }
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
        case .failed(let error):
            ErrorView(message: error) {
                Task { await viewModel.load() }
            }
        case .loaded(let messages) where messages.isEmpty && viewModel.typingUserIds.isEmpty:
            if viewModel.isInitialLoading {
                Color.clear
            } else {
                EmptyStateView(
                    icon: "bubble.left",
                    title: languageService.text(.messagingChatEmptyTitle),
                    message: languageService.text(.messagingChatEmptyMessage)
                )
            }
        default:
            ChatMessageListView(
                viewModel: viewModel,
                messages: viewModel.messages,
                currentUserId: currentUserId,
                senderDisplayName: senderDisplayName(for:),
                userDisplayName: userDisplayName(for:),
                onRequestComposerFocus: { isInputFocused = true },
                onDismissKeyboard: { isInputFocused = false },
                peerAvatarURL: peer?.avatarUrl.flatMap(URL.init(string:)),
                peerDisplayName: peer?.displayTitle ?? "",
                showsPeerReadAvatar: displayConversation?.isGroup != true,
                conversationId: viewModel.conversationId,
                isComposerFocused: isInputFocused,
                bottomOverlayInset: SplickTheme.Spacing.sm
            )
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
                onRevealReplyOriginal: {
                    guard let originId = viewModel.replyDraft?.messageId else { return }
                    Task { await viewModel.revealSearchedMessage(id: originId) }
                },
                placeholder: languageService.text(.messagingInputPlaceholder),
                isSending: viewModel.isSending,
                errorMessage: nil,
                onSend: { text, submissions in
                    viewModel.stopLocalTyping()
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

    private func userDisplayName(for userId: UUID) -> String {
        if userId == currentUserId {
            return languageService.text(.messagingYou)
        }
        if let peer, peer.userId == userId {
            return peer.displayTitle
        }
        if let name = resolvedSenderDisplayName(userId, on: nil) {
            return name
        }
        return languageService.text(.messagingReplyUnknownSender)
    }

    private func resolvedSenderDisplayName(_ senderId: UUID, on message: ChatMessage?) -> String? {
        if let peer, peer.userId == senderId {
            return peer.displayTitle
        }
        if let message, let name = trimmedDisplayName(message.senderDisplayName) {
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

    private func resolvedPresence(for peer: ConversationPeer) -> (isOnline: Bool, lastSeenAt: Date?) {
        if let state = presenceStore.state(for: peer.userId) {
            return (state.isOnline, state.lastSeenAt)
        }
        return (peer.isOnline ?? false, peer.lastSeenAt)
    }

    private var headerPresenceSubtitle: String? {
        guard let peer, displayConversation?.isGroup != true else { return nil }
        let presence = resolvedPresence(for: peer)
        return PresenceDisplayPolicy.lastSeenText(
            isOnline: presence.isOnline,
            lastSeenAt: presence.lastSeenAt,
            appLocale: languageService.locale
        )
    }
}
