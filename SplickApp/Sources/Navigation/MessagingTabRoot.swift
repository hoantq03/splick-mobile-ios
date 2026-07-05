import SwiftUI
import FeatureMessaging
import FeatureSocialFeed
import SplickDomain

/// App-layer host that wires the feed emoji picker into messaging reactions.
struct MessagingTabRoot: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var appState: AppState

    @State private var showsReactionPicker = false
    @State private var reactionPickHandler: ((String) -> Void)?

    var body: some View {
        ConversationListView(
            viewModel: container.conversationListViewModel,
            createGroupViewModel: container.createGroupConversationViewModel,
            friendsProvider: {
                try await container.fetchMyFriendsUseCase.execute()
            }
        )
        .environmentObject(container.makeChatThreadViewModelFactory(
            currentUserId: appState.currentUser?.id ?? UUID()
        ))
        .environment(\.messagingReactionPicker, MessagingReactionPickerAction { onPick in
            reactionPickHandler = onPick
            showsReactionPicker = true
        })
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
