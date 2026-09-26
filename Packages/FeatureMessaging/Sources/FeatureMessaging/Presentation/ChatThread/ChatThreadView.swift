import SwiftUI
import UIKit
import Common
import DesignSystem
import Localization
import Networking
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
    @State private var isSearchingThread = false
    @State private var threadSearchDraft = ""
    @FocusState private var isThreadSearchFocused: Bool

    private let currentUserId: UUID
    private let peer: ConversationPeer?
    private let navigationTitle: String
    private let conversation: Conversation?
    private let repository: MessagingRepositoryProtocol?
    private let onConversationUpdated: ((Conversation) -> Void)?
    private let onConversationDeleted: ((UUID) -> Void)?

    @State private var groupConversation: Conversation?
    @State private var activeGroupSheet: GroupChatSheet?
    @State private var confirmLeaveGroup = false
    @State private var confirmDisbandGroup = false
    @State private var showTransferBeforeLeave = false
    @State private var leaveError: String?
    @State private var confirmDeleteConversation = false
    @State private var confirmRecallMessageId: UUID?
    @State private var comingSoonFeatureTitle: String?
    @State private var showMuteDurationPicker = false
    @State private var pendingPeerConfirm: PendingPeerConfirm?
    @State private var detailsMessage: ChatMessage?
    @State private var isDetailsPresented = false
    @State private var reactionFocus: MessageReactionFocusContext?

    @Environment(\.chatGroupManagementActions) private var groupManagementActions
    @Environment(\.presentInviteFriendsToGroup) private var presentInviteFriendsToGroup
    @Environment(\.transferSocialGroupOwnership) private var transferSocialGroupOwnership
    @Environment(\.leaveSocialGroupMembership) private var leaveSocialGroupMembership
    @Environment(\.dismiss) private var dismiss
    @Environment(\.messagingReactionPicker) private var reactionPicker

    public init(
        viewModel: ChatThreadViewModel,
        relationshipViewModel: ChatPeerRelationshipViewModel,
        currentUserId: UUID,
        peer: ConversationPeer? = nil,
        navigationTitle: String = "",
        conversation: Conversation? = nil,
        repository: MessagingRepositoryProtocol? = nil,
        onConversationUpdated: ((Conversation) -> Void)? = nil,
        onConversationDeleted: ((UUID) -> Void)? = nil
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._relationshipViewModel = ObservedObject(wrappedValue: relationshipViewModel)
        self.currentUserId = currentUserId
        self.peer = peer
        self.navigationTitle = navigationTitle
        self.conversation = conversation
        self.repository = repository
        self.onConversationUpdated = onConversationUpdated
        self.onConversationDeleted = onConversationDeleted
    }

    public var body: some View {
        ZStack {
            threadContent
                .opacity(isSearchingThread ? 0 : 1)
                .animation(.none, value: isSearchingThread)
                .allowsHitTesting(!isSearchingThread)
                .accessibilityHidden(isSearchingThread)
                .scrollDisabled(isSearchingThread)
            if let peer, displayConversation?.isGroup != true {
                ChatThreadPresenceSideEffects(
                    peerUserId: peer.userId,
                    isBlocked: relationshipViewModel.isBlocked,
                    canRemoveFriend: relationshipViewModel.canRemoveFriend
                )
            }
            reactionFocusCover
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(SplickTheme.Colors.background.ignoresSafeArea())
                .zIndex(20)
                .transition(.opacity)
            }
        }
        .navigationDestination(isPresented: $isDetailsPresented) {
            messageDetailsDestination
        }
        .background(SplickTheme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(reactionFocus == nil ? .automatic : .hidden, for: .navigationBar)
        .toolbarBackground(reactionFocus == nil ? .automatic : .hidden, for: .tabBar)
        // Edge-only pop: disables widened pop band so swipe-to-reply is not stolen.
        .splickEdgeOnlyInteractivePop()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: openChatHeader) {
                    ChatThreadNavigationTitle(
                        isGroup: displayConversation?.isGroup == true,
                        peer: peer,
                        title: displayConversation?.displayTitle ?? navigationTitle,
                        navigationTitle: navigationTitle,
                        groupAvatarURL: displayConversation?.groupAvatarUrl,
                        showsPeerPresence: showsPeerPresence
                    )
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
                        applyConversationUpdate(updated.updating(groupName: name))
                        if let notice = updated.lastMessage, notice.isSystemNotice {
                            viewModel.upsertIncomingMessage(notice, animate: true, scrollToBottom: true)
                        }
                    }
                case .avatar:
                    GroupAvatarSheet(
                        groupName: displayConversation.displayTitle,
                        currentAvatarURL: messagingAvatarURL(displayConversation.groupAvatarUrl)
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
                        },
                        transferAdmin: { groupId, newAdminUserId in
                            try await transferGroupLeadership(
                                groupId: groupId,
                                newAdminUserId: newAdminUserId
                            )
                        },
                        onTransferred: {
                            Task {
                                await viewModel.refreshGroupViewerRole(isGroup: true)
                            }
                        },
                        onAddMembers: { memberIds in
                            activeGroupSheet = nil
                            presentCenteredConfirm {
                                presentInviteFriendsToGroup?(
                                    InviteFriendsToGroupRequest(
                                        groupId: displayConversation.id,
                                        existingMemberIds: memberIds
                                    )
                                )
                            }
                        }
                    )
                case .transferAdmin:
                    TransferGroupAdminSheet(
                        groupId: displayConversation.id,
                        currentUserId: currentUserId,
                        fetchMembers: groupManagementActions.fetchMembers,
                        transferAdmin: { groupId, newAdminUserId in
                            try await transferGroupLeadership(
                                groupId: groupId,
                                newAdminUserId: newAdminUserId
                            )
                        },
                        onTransferred: {
                            Task {
                                await viewModel.refreshGroupViewerRole(isGroup: true)
                                await leaveGroup()
                            }
                        }
                    )
                }
            }
        }
        .confirmationDialog(
            languageService.text(.messagingChatMuteFor),
            isPresented: $showMuteDurationPicker,
            titleVisibility: .visible
        ) {
            ForEach(ConversationMutePreset.allCases, id: \.self) { preset in
                Button(languageService.text(preset.titleKey)) {
                    muteThreadNotifications(preset)
                }
            }
            Button(languageService.text(.commonCancel), role: .cancel) {}
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
            languageService.text(.messagingGroupDisbandConfirmTitle),
            isPresented: $confirmDisbandGroup,
            titleVisibility: .visible
        ) {
            Button(languageService.text(.messagingGroupDisband), role: .destructive) {
                Task { await disbandGroup() }
            }
            Button(languageService.text(.commonCancel), role: .cancel) {}
        } message: {
            Text(languageService.text(.messagingGroupDisbandConfirmMessage))
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
            languageService.text(.messagingRecallConfirmTitle),
            isPresented: Binding(
                get: { confirmRecallMessageId != nil },
                set: { if !$0 { confirmRecallMessageId = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(languageService.text(.messagingRecallAction), role: .destructive) {
                guard let messageId = confirmRecallMessageId else { return }
                confirmRecallMessageId = nil
                Task { await viewModel.recallMessage(id: messageId) }
            }
            Button(languageService.text(.commonCancel), role: .cancel) {
                confirmRecallMessageId = nil
            }
        } message: {
            Text(languageService.text(.messagingRecallConfirmMessage))
        }
        .alert(
            pendingPeerConfirmTitle,
            isPresented: Binding(
                get: { pendingPeerConfirm != nil },
                set: { if !$0 { pendingPeerConfirm = nil } }
            )
        ) {
            Button(languageService.text(.commonCancel), role: .cancel) {
                pendingPeerConfirm = nil
            }
            Button(pendingPeerConfirmActionTitle, role: .destructive) {
                confirmPendingPeerAction()
            }
        }
        .alert(languageService.text(.commonError), isPresented: Binding(
            get: { leaveError != nil },
            set: { if !$0 { leaveError = nil } }
        )) {
            Button(languageService.text(.commonOK), role: .cancel) { leaveError = nil }
        } message: {
            Text(leaveError ?? "")
        }
        .alert(
            languageService.text(.friendsTransferBeforeLeaveTitle),
            isPresented: $showTransferBeforeLeave
        ) {
            Button(languageService.text(.friendsStay), role: .cancel) {
                showTransferBeforeLeave = false
            }
            Button(languageService.text(.friendsTransferOwnership)) {
                showTransferBeforeLeave = false
                activeGroupSheet = .transferAdmin
            }
        } message: {
            Text(languageService.text(.friendsTransferBeforeLeave))
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
        .onChange(of: relationshipViewModel.isBlocked) { isBlocked in
            guard isBlocked else { return }
            inputText = ""
            viewModel.attachmentDrafts = []
            viewModel.cancelReply()
            isInputFocused = false
        }
        .onChange(of: relationshipViewModel.showsAddFriendBanner) { showsBanner in
            guard showsBanner else { return }
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
            // Inbox owns showing the tab bar when the stack is empty. Revealing it
            // here races when a notification replaces this thread with another.
        }
        .onChange(of: isDetailsPresented) { presented in
            if presented {
                tabBarScrollState?.hide(flushToBottom: true)
            } else {
                detailsMessage = nil
                tabBarScrollState?.hide(flushToBottom: true)
            }
        }
        .onChange(of: inputText) { newValue in
            viewModel.onComposerTextChanged(newValue)
        }
        .task(id: viewModel.conversationId) {
            await viewModel.loadIfNeeded()
            async let relationship: Void = relationshipViewModel.loadIfNeeded()
            async let groupRole: Void = viewModel.refreshGroupViewerRole(
                isGroup: (groupConversation ?? conversation)?.isGroup == true
            )
            _ = await (relationship, groupRole)
        }
    }

    private var displayConversation: Conversation? {
        groupConversation ?? conversation
    }

    private var groupCapabilities: GroupChatThreadCapabilities {
        viewModel.groupThreadCapabilities(isGroup: displayConversation?.isGroup == true)
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
            // Only the message list dismisses the keyboard on tap — never the composer.
            // Applying dismissKeyboardOnTap to the whole thread made Send resign focus
            // (SwiftUI button hit targets are often not UIControl / "Button").
            messageArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .dismissKeyboardOnTap()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !isDetailsPresented {
                        bottomBar
                    }
                }
        }
    }

    @ViewBuilder
    private var reactionFocusCover: some View {
        if let focus = reactionFocus {
            GeometryReader { geo in
                MessageReactionFocusOverlay(
                    context: focus.localized(overlayOrigin: geo.frame(in: .global).origin),
                    allowsThreadInteraction: groupCapabilities.canInteractWithMessages
                        && !relationshipViewModel.isBlocked
                        && relationshipViewModel.canComposeMessages
                        && !focus.displayMessage.message.recalled,
                    canEdit: focus.displayMessage.message.isEditable(by: currentUserId)
                        && relationshipViewModel.canComposeMessages,
                    canRecall: focus.displayMessage.message.isRecallable(by: currentUserId)
                        && groupCapabilities.canInteractWithMessages
                        && !relationshipViewModel.isBlocked
                        && relationshipViewModel.canComposeMessages,
                    onReact: { emoji in
                        _ = viewModel.react(to: focus.messageId, emoji: emoji)
                    },
                    onReply: {
                        guard let message = viewModel.messages.first(where: { $0.id == focus.messageId }) else {
                            return
                        }
                        viewModel.beginReply(
                            to: message,
                            senderDisplayName: senderDisplayName(for: message)
                        )
                        isInputFocused = true
                    },
                    onEdit: {
                        guard let message = viewModel.messages.first(where: { $0.id == focus.messageId }) else {
                            return
                        }
                        if let body = viewModel.beginEdit(message) {
                            inputText = body
                            isInputFocused = true
                        }
                    },
                    onRecall: {
                        confirmRecallMessageId = focus.messageId
                    },
                    onCopy: {
                        let body = focus.displayMessage.message.body
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !body.isEmpty else { return }
                        UIPasteboard.general.string = body
                    },
                    onDetails: {
                        reactionFocus = nil
                        openMessageDetails(focus.displayMessage.message)
                    },
                    onOpenFullPicker: {
                        reactionPicker.present { emoji in
                            _ = viewModel.react(to: focus.messageId, emoji: emoji)
                        }
                    },
                    onDismiss: { reactionFocus = nil },
                    onForceDismiss: { reactionFocus = nil }
                )
                .id(focus.session)
            }
            .ignoresSafeArea()
            .zIndex(100)
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
        let notificationsMuted = displayConversation?.isMuted() ?? false
        Button {
            openThreadSearch()
        } label: {
            Label(
                languageService.text(.messagingChatSearchMessages),
                systemImage: "magnifyingglass"
            )
        }

        Button {
            if notificationsMuted {
                unmuteThreadNotifications()
            } else {
                showMuteDurationPicker = true
            }
        } label: {
            Label(
                languageService.text(
                    notificationsMuted
                        ? .messagingChatUnmuteNotifications
                        : .messagingChatMuteNotifications
                ),
                systemImage: notificationsMuted ? "bell" : "bell.slash"
            )
        }
        .disabled(repository == nil)
    }

    @ViewBuilder
    private var closeFriendMenuAction: some View {
        if relationshipViewModel.canRemoveFriend, displayConversation?.isGroup != true {
            let isCloseFriend = displayConversation?.closeFriend == true
            Button {
                toggleCloseFriend()
            } label: {
                Label(
                    languageService.text(
                        isCloseFriend
                            ? .messagingChatRemoveCloseFriend
                            : .messagingChatAddCloseFriend
                    ),
                    systemImage: isCloseFriend ? "star.slash.fill" : "star.fill"
                )
            }
            .disabled(repository == nil)
        }
    }

    @ViewBuilder
    private var deleteConversationAction: some View {
        Button(role: .destructive) {
            presentCenteredConfirm { confirmDeleteConversation = true }
        } label: {
            Label(
                languageService.text(.messagingChatDeleteConversation),
                systemImage: "trash"
            )
        }
        .disabled(repository == nil)
    }

    private var groupChatOptionsMenu: some View {
        Menu {
            if groupCapabilities.canSearch || groupCapabilities.canManageNotifications {
                conversationComingSoonActions
            }

            if groupCapabilities.canChangeAvatar {
                Button {
                    activeGroupSheet = .avatar
                } label: {
                    Label(
                        languageService.text(.messagingGroupChangeAvatar),
                        systemImage: "photo.circle"
                    )
                }
            }

            if groupCapabilities.canRename {
                Button {
                    activeGroupSheet = .rename
                } label: {
                    Label(
                        languageService.text(.messagingGroupChangeName),
                        systemImage: "pencil"
                    )
                }
            }

            if groupCapabilities.canManageMembers {
                Button {
                    activeGroupSheet = .members
                } label: {
                    Label(
                        languageService.text(.messagingGroupManageMembers),
                        systemImage: "person.2"
                    )
                }
            }

            if groupCapabilities.canInviteMembers {
                Button {
                    presentInviteMembers()
                } label: {
                    Label(
                        languageService.text(.friendsAddMembersTitle),
                        systemImage: "person.badge.plus"
                    )
                }
            }

            if groupCapabilities.canLeave {
                Button(role: .destructive) {
                    confirmLeaveGroup = true
                } label: {
                    Label(
                        languageService.text(.messagingLeaveGroup),
                        systemImage: "rectangle.portrait.and.arrow.right"
                    )
                }
            }

            if groupCapabilities.canDisbandGroup {
                Button(role: .destructive) {
                    confirmDisbandGroup = true
                } label: {
                    Label(
                        languageService.text(.messagingGroupDisband),
                        systemImage: "xmark.circle"
                    )
                }
            }

            if groupCapabilities.canDeleteConversation {
                deleteConversationAction
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
        case transferAdmin

        var id: String {
            switch self {
            case .rename: return "rename"
            case .avatar: return "avatar"
            case .members: return "members"
            case .transferAdmin: return "transferAdmin"
            }
        }
    }

    private enum PendingPeerConfirm {
        case removeFriend
        case blockUser
    }

    private func presentInviteMembers() {
        guard let displayConversation else { return }
        Task {
            let members = (try? await groupManagementActions.fetchMembers(displayConversation.id)) ?? []
            var excluded = Set(members.map(\.userId))
            excluded.insert(currentUserId)
            presentInviteFriendsToGroup?(
                InviteFriendsToGroupRequest(
                    groupId: displayConversation.id,
                    existingMemberIds: excluded
                )
            )
        }
    }

    private func applyConversationUpdate(_ updated: Conversation) {
        groupConversation = updated
        onConversationUpdated?(updated)
    }

    private func unmuteThreadNotifications() {
        applyThreadNotificationSettings(enabled: true, mutedUntil: nil)
    }

    private func muteThreadNotifications(_ preset: ConversationMutePreset) {
        applyThreadNotificationSettings(
            enabled: false,
            mutedUntil: ConversationMuteSchedule.mutedUntil(preset: preset)
        )
    }

    private func applyThreadNotificationSettings(enabled: Bool, mutedUntil: Date?) {
        guard let displayConversation, let repository else { return }
        let previous = displayConversation
        AppNotificationSound.playMuteToggleFeedback(enablingNotifications: enabled)
        applyConversationUpdate(
            previous.updatingNotificationSettings(
                enabled: enabled,
                sound: previous.notificationSound,
                mutedUntil: mutedUntil
            )
        )
        Task {
            do {
                let updated = try await repository.updateNotificationSettings(
                    conversationId: previous.id,
                    notificationsEnabled: enabled,
                    notificationSound: previous.notificationSound,
                    mutedUntil: mutedUntil
                )
                applyConversationUpdate(
                    previous.updatingNotificationSettings(
                        enabled: updated.notificationsEnabled,
                        sound: updated.notificationSound,
                        mutedUntil: updated.mutedUntil
                    )
                )
            } catch {
                applyConversationUpdate(previous)
                leaveError = languageService.localizedMessage(for: error)
            }
        }
    }

    private func toggleCloseFriend() {
        guard let displayConversation, let peerId = displayConversation.peer?.userId, let repository else { return }
        guard !displayConversation.isGroup, relationshipViewModel.canRemoveFriend else { return }
        let previous = displayConversation
        let enabled = !previous.closeFriend
        applyConversationUpdate(previous.updating(closeFriend: enabled))
        Task {
            do {
                let confirmed = try await repository.setCloseFriend(friendUserId: peerId, enabled: enabled)
                applyConversationUpdate(previous.updating(closeFriend: confirmed))
            } catch {
                applyConversationUpdate(previous)
                leaveError = languageService.localizedMessage(for: error)
            }
        }
    }

    /// Wait for the overflow `Menu` to dismiss so the confirm alert anchors to the
    /// full screen (center) instead of the disappearing menu popover.
    private func presentCenteredConfirm(_ present: @escaping () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            present()
        }
    }

    private var pendingPeerConfirmTitle: String {
        switch pendingPeerConfirm {
        case .blockUser:
            return languageService.text(.friendsBlockConfirmTitle)
        case .removeFriend, nil:
            return languageService.text(.friendsRemoveFriendConfirmTitle)
        }
    }

    private var pendingPeerConfirmActionTitle: String {
        switch pendingPeerConfirm {
        case .blockUser:
            return languageService.text(.friendsBlockConfirmAction)
        case .removeFriend, nil:
            return languageService.text(.friendsRemoveFriendConfirmAction)
        }
    }

    private func confirmPendingPeerAction() {
        let confirm = pendingPeerConfirm
        pendingPeerConfirm = nil
        Task {
            switch confirm {
            case .removeFriend:
                await relationshipViewModel.removeFriend()
            case .blockUser:
                await relationshipViewModel.blockUser()
            case nil:
                break
            }
        }
    }

    private func transferGroupLeadership(groupId: UUID, newAdminUserId: UUID) async throws {
        if let transferSocialGroupOwnership {
            do {
                try await transferSocialGroupOwnership(groupId, newAdminUserId)
            } catch {
                if !error.isIgnorableSocialOwnershipTransfer {
                    throw error
                }
            }
        }
        guard let repository else { return }
        try await repository.transferGroupAdmin(groupId: groupId, newAdminUserId: newAdminUserId)
    }

    private func leaveGroup() async {
        guard let displayConversation, let repository else { return }
        do {
            try await repository.leaveGroup(groupId: displayConversation.id)
            if let leaveSocialGroupMembership {
                do {
                    try await leaveSocialGroupMembership(displayConversation.id)
                } catch {
                    if error.isOwnershipTransferRequired {
                        showTransferBeforeLeave = true
                        return
                    }
                    if !error.isIgnorableSocialLeaveAfterMessaging {
                        leaveError = languageService.localizedMessage(for: error)
                        return
                    }
                }
            }
            GroupsDirectoryChange.post()
            onConversationDeleted?(displayConversation.id)
            dismiss()
        } catch {
            if error.isOwnershipTransferRequired {
                showTransferBeforeLeave = true
            } else {
                leaveError = languageService.localizedMessage(for: error)
            }
        }
    }

    private func disbandGroup() async {
        guard let displayConversation else { return }
        do {
            try await groupManagementActions.deleteGroup(displayConversation.id)
            onConversationDeleted?(displayConversation.id)
            dismiss()
        } catch {
            leaveError = languageService.localizedMessage(for: error)
        }
    }

    private func deleteConversation() async {
        guard let displayConversation, let repository else { return }
        do {
            try await repository.deleteConversation(conversationId: displayConversation.id)
            viewModel.clearCachedThread()
            onConversationDeleted?(displayConversation.id)
            dismiss()
        } catch {
            // Delete errors surface on next navigation refresh; keep UX simple here.
        }
    }

    private var directChatOptionsMenu: some View {
        Menu {
            conversationComingSoonActions
            closeFriendMenuAction

            if relationshipViewModel.isActive, !relationshipViewModel.isBlocked {
                if relationshipViewModel.canRemoveFriend {
                    Button(role: .destructive) {
                        presentCenteredConfirm { pendingPeerConfirm = .removeFriend }
                    } label: {
                        Label(
                            languageService.text(.friendsRemoveFriend),
                            systemImage: "person.badge.minus"
                        )
                    }
                }
                Button(role: .destructive) {
                    presentCenteredConfirm { pendingPeerConfirm = .blockUser }
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
        if viewModel.isRemovedFromGroup {
            removedFromGroupFooter
        } else if relationshipViewModel.isBlocked {
            blockedFooter
        } else if relationshipViewModel.showsAddFriendBanner {
            notFriendsComposerFooter
        } else if relationshipViewModel.canComposeMessages {
            inputBar
        }
    }

    private var notFriendsComposerFooter: some View {
        Text(addFriendBannerMessage)
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.background)
    }

    private var removedFromGroupFooter: some View {
        Text(languageService.text(.messagingGroupRemovedFooter))
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm)
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

    private func openMessageDetails(_ message: ChatMessage) {
        isInputFocused = false
        detailsMessage = message
        isDetailsPresented = true
    }

    @ViewBuilder
    private var messageDetailsDestination: some View {
        if let detailsMessage {
            MessageDetailsSheet(
                message: detailsMessage,
                displayNameForUserId: userDisplayName(for:)
            )
            .splickEdgeOnlyInteractivePop()
        } else {
            Color.clear
        }
    }

    private func openChatHeader() {
        guard let peer, let openUserProfile else { return }
        let user = UserSummary(
            id: peer.userId,
            username: peer.username,
            displayName: peer.displayTitle,
            avatarURL: messagingAvatarURL(peer.avatarUrl)
        )
        guard user.id != currentUserSummary?.id else { return }
        openUserProfile(user)
    }

    @ViewBuilder
    private var messageArea: some View {
        switch viewModel.state {
        case .failed(let error):
            ErrorView(
                message: error,
                isLoading: viewModel.isInitialLoading,
                isFailed: true
            ) {
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
                peerAvatarURL: messagingAvatarURL(peer?.avatarUrl),
                peerDisplayName: peer?.displayTitle ?? "",
                showsPeerReadAvatar: displayConversation?.isGroup != true,
                conversationId: viewModel.conversationId,
                bottomOverlayInset: SplickTheme.Spacing.sm,
                onOpenDetails: openMessageDetails,
                allowsThreadInteraction: groupCapabilities.canInteractWithMessages
                    && !relationshipViewModel.isBlocked
                    && relationshipViewModel.canComposeMessages,
                onBeginEdit: { message in
                    if let body = viewModel.beginEdit(message) {
                        inputText = body
                        isInputFocused = true
                    }
                },
                onRequestRecall: { messageId in
                    confirmRecallMessageId = messageId
                },
                reactionFocus: $reactionFocus
            )
            .overlay(alignment: .bottom) {
                JumpToLatestChip(
                    visible: viewModel.showJumpToLatest,
                    onTap: { viewModel.pinToLatest() }
                )
                .padding(.bottom, SplickTheme.Spacing.sm)
            }
        }
    }

    @ViewBuilder
    private var inputBar: some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            MessageComposerInputBar(
                text: $inputText,
                attachmentDrafts: $viewModel.attachmentDrafts,
                replyDraft: viewModel.replyDraft,
                onCancelReply: { viewModel.cancelReply() },
                onRevealReplyOriginal: {
                    guard let originId = viewModel.replyDraft?.messageId else { return }
                    Task { await viewModel.revealSearchedMessage(id: originId) }
                },
                editDraft: viewModel.editDraft,
                onCancelEdit: {
                    viewModel.cancelEdit()
                    inputText = ""
                },
                placeholder: languageService.text(.messagingInputPlaceholder),
                isSending: viewModel.isSending,
                errorMessage: viewModel.mutationError,
                onSend: { text, submissions in
                    viewModel.stopLocalTyping()
                    let isEditing = viewModel.editDraft != nil
                    // UIKit send control keeps first responder; keep FocusState aligned.
                    isInputFocused = true
                    inputText = ""
                    Task { @MainActor in
                        await viewModel.send(body: text, submissions: submissions)
                        isInputFocused = true
                        if !isEditing {
                            viewModel.dismissMutationError()
                        }
                    }
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

    private var showsPeerPresence: Bool {
        switch relationshipViewModel.status {
        case .unknown, .friends:
            return true
        default:
            return false
        }
    }
}

/// Isolated so presence heartbeats do not invalidate the message list.
private struct ChatThreadNavigationTitle: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var presenceStore: PresenceStore

    let isGroup: Bool
    let peer: ConversationPeer?
    let title: String
    let navigationTitle: String
    let groupAvatarURL: String?
    let showsPeerPresence: Bool

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            if !isGroup, let peer {
                let presence = resolvedPresence(for: peer)
                AvatarWithPresenceView(
                    imageURL: messagingAvatarURL(peer.avatarUrl),
                    name: navigationTitle,
                    size: .compact,
                    userId: peer.userId,
                    showOnlineIndicator: showsPeerPresence && PresenceDisplayPolicy.shouldShowOnlineIndicator(
                        isOnline: presence.isOnline
                    ),
                    lastSeenLabel: showsPeerPresence
                        ? PresenceDisplayPolicy.compactLastSeenLabel(
                            isOnline: presence.isOnline,
                            lastSeenAt: presence.lastSeenAt,
                            appLocale: languageService.locale
                        )
                        : nil
                )
            } else {
                AvatarView(
                    imageURL: headerAvatarURL,
                    name: navigationTitle,
                    size: .compact
                )
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .id(title)
            }
        }
    }

    private var headerAvatarURL: URL? {
        messagingAvatarURL(isGroup ? groupAvatarURL : peer?.avatarUrl)
    }

    private func resolvedPresence(for peer: ConversationPeer) -> (isOnline: Bool, lastSeenAt: Date?) {
        let stored = presenceStore.state(for: peer.userId)
        let isOnline = (stored?.isOnline ?? false) || (peer.isOnline ?? false)
        let lastSeenAt = stored?.lastSeenAt ?? peer.lastSeenAt
        return (isOnline, lastSeenAt)
    }
}

/// Clears stale presence after block/unfriend without observing the store on the thread view.
private struct ChatThreadPresenceSideEffects: View {
    @EnvironmentObject private var presenceStore: PresenceStore
    let peerUserId: UUID
    let isBlocked: Bool
    let canRemoveFriend: Bool

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: isBlocked) { blocked in
                if blocked {
                    presenceStore.clear(userId: peerUserId)
                }
            }
            .onChange(of: canRemoveFriend) { canRemove in
                if !canRemove {
                    presenceStore.clear(userId: peerUserId)
                }
            }
    }
}

private func messagingAvatarURL(_ raw: String?) -> URL? {
    guard let raw, !raw.isEmpty else { return nil }
    return URL(string: raw)
}

private extension Error {
    var isOwnershipTransferRequired: Bool {
        if case .apiError(let code, _, _) = self as? NetworkError {
            return code.caseInsensitiveCompare("OWNERSHIP_TRANSFER_REQUIRED") == .orderedSame
        }
        return false
    }

    var isIgnorableSocialOwnershipTransfer: Bool {
        guard let network = self as? NetworkError else { return false }
        switch network {
        case .forbidden, .notFound:
            return true
        default:
            return false
        }
    }

    var isIgnorableSocialLeaveAfterMessaging: Bool {
        guard let network = self as? NetworkError else { return false }
        switch network {
        case .forbidden, .notFound:
            return true
        default:
            return false
        }
    }
}
