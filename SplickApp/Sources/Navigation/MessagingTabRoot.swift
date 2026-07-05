import SwiftUI
import FeatureMessaging
import FeatureSocialFeed
import FeatureFriends
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

    var body: some View {
        ConversationListView(
            viewModel: container.conversationListViewModel,
            createGroupViewModel: container.createGroupConversationViewModel,
            friendsProvider: {
                try await container.fetchMyFriendsUseCase.execute()
            }
        )
        .environmentObject(container.customEmojiStore)
        .environment(\.customEmojiDependencies, container.customEmojiDependencies)
        .environmentObject(container.makeChatThreadViewModelFactory(
            currentUserId: appState.currentUser?.id ?? UUID()
        ))
        .environment(\.chatPeerRelationshipActions, container.makeChatPeerRelationshipActions())
        .environment(\.messagingReactionPicker, MessagingReactionPickerAction { onPick in
            reactionPickHandler = onPick
            showsReactionPicker = true
        })
        .environment(\.openUserProfile) { user in
            profileRoute = MessagingUserProfileRoute(user: user)
        }
        .sheet(item: $profileRoute) { route in
            FriendUserProfileView(
                viewModel: container.friendUserProfileDependencies.makeViewModel(user: route.user)
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
}
