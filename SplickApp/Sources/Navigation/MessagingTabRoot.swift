import SwiftUI
import DesignSystem
import FeatureMessaging
import FeatureSocialFeed
import FeatureFriends
import FeatureStickers
import SplickDomain

private struct MessagingUserProfileRoute: Identifiable {
    let user: UserSummary
    var id: UUID { user.id }
}

/// App-layer host that wires the feed emoji picker into messaging reactions.
struct MessagingTabRoot: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var appState: AppState

    @State private var showsReactionPicker = false
    @State private var reactionPickHandler: ((String) -> Void)?
    @State private var profileRoute: MessagingUserProfileRoute?
    @State private var showCreateGroup = false
    @State private var createGroupFriends: [UserSummary] = []
    @State private var conversationRouteToOpen: ChatThreadRoute?

    var body: some View {
        ConversationListView(
            viewModel: container.conversationListViewModel,
            onCreateGroup: {
                Task {
                    createGroupFriends = (try? await container.fetchMyFriendsUseCase.execute()) ?? []
                    showCreateGroup = true
                }
            },
            makeComposeViewModel: {
                container.makeNewMessageComposeViewModel(
                    currentUserId: appState.currentUser?.id ?? UUID()
                )
            },
            conversationToOpen: $conversationRouteToOpen
        )
        .environmentObject(container.customEmojiStore)
        .environment(\.customEmojiDependencies, container.customEmojiDependencies)
        .environment(\.messagingGifPickerFactory) {
            container.makeGifPickerViewModel(groupId: nil)
        }
        .environment(
            \.imageAttachmentUpload,
            { data, mimeType in
                let upload = try await container.uploadCommentAttachment(data: data, mimeType: mimeType)
                return UploadedMediaReference(
                    id: upload.id,
                    url: upload.url,
                    thumbnailURL: upload.thumbnailURL,
                    sizeBytes: upload.sizeBytes
                )
            }
        )
        .environmentObject(container.makeChatThreadViewModelFactory(
            currentUserId: appState.currentUser?.id ?? UUID()
        ))
        .environment(\.chatPeerRelationshipActions, container.makeChatPeerRelationshipActions())
        .environment(\.chatGroupManagementActions, container.makeChatGroupManagementActions())
        .environment(\.messagingReactionPicker, MessagingReactionPickerAction { onPick in
            reactionPickHandler = onPick
            showsReactionPicker = true
        })
        .environment(\.openUserProfile) { user in
            profileRoute = MessagingUserProfileRoute(user: user)
        }
        .onChange(of: appState.pendingMessagingNavigation?.conversationId) { _ in
            guard let navigation = appState.pendingMessagingNavigation else { return }
            Task {
                await openConversation(from: navigation)
                appState.clearPendingMessagingNavigation()
            }
        }
        .sheet(item: $profileRoute) { route in
            FriendUserProfileView(
                viewModel: container.friendUserProfileDependencies.makeViewModel(user: route.user)
            )
            .environmentObject(container.languageService)
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupSheet(
                viewModel: CreateGroupViewModel(
                    friends: createGroupFriends,
                    createGroupUseCase: container.createGroupUseCase,
                    inviteFriendsUseCase: container.inviteFriendsToGroupUseCase,
                    uploadGroupAvatarUseCase: container.uploadGroupAvatarUseCase,
                    updateGroupAvatarUseCase: container.updateGroupAvatarUseCase
                ) { group, invitedMemberIds in
                    showCreateGroup = false
                    Task {
                        await container.openMessagingGroupChat(
                            group: group,
                            invitedMemberIds: invitedMemberIds,
                            conversationListViewModel: container.conversationListViewModel,
                            onOpen: { conversationRouteToOpen = ChatThreadRoute(conversation: $0) }
                        )
                    }
                }
            )
            .environmentObject(container.languageService)
        }
        .sheet(isPresented: $showsReactionPicker, onDismiss: {
            reactionPickHandler = nil
        }) {
            EmojiPickerSheet(
                currentUserId: appState.currentUser?.id,
                mode: .reaction
            ) { emoji in
                reactionPickHandler?(emoji)
                showsReactionPicker = false
            }
            .environmentObject(container.languageService)
            .environmentObject(container.customEmojiStore)
            .environment(\.customEmojiDependencies, container.customEmojiDependencies)
        }
    }

    private func openConversation(from navigation: PendingMessagingNavigation) async {
        let conversationId = navigation.conversationId
        if let existing = container.conversationListViewModel.conversations.first(where: { $0.id == conversationId }) {
            conversationRouteToOpen = ChatThreadRoute(
                conversation: existing,
                highlightMessageId: navigation.highlightMessageId
            )
            return
        }

        await container.conversationListViewModel.refresh()
        if let refreshed = container.conversationListViewModel.conversations.first(where: { $0.id == conversationId }) {
            conversationRouteToOpen = ChatThreadRoute(
                conversation: refreshed,
                highlightMessageId: navigation.highlightMessageId
            )
            return
        }

        let fallback = Conversation(
            id: conversationId,
            unreadCount: 0,
            peer: nil,
            lastMessage: nil,
            createdAt: .now,
            updatedAt: .now
        )
        conversationRouteToOpen = ChatThreadRoute(
            conversation: fallback,
            highlightMessageId: navigation.highlightMessageId
        )
    }
}
