import SwiftUI
import Storage
import SplickDomain

struct ChatThreadNavigationWrapper: View {
    let conversation: Conversation

    @EnvironmentObject private var chatThreadViewModelFactory: ChatThreadViewModelFactory

    var body: some View {
        let viewModel = chatThreadViewModelFactory.make(conversationId: conversation.id)
        ChatThreadView(
            viewModel: viewModel,
            currentUserId: chatThreadViewModelFactory.currentUserId,
            navigationTitle: conversation.peer?.displayTitle ?? ""
        )
    }
}

/// Factory injected via environment to create ChatThreadViewModel per conversation.
public final class ChatThreadViewModelFactory: ObservableObject {
    public let currentUserId: UUID
    private let fetchMessagesUseCase: FetchMessagesUseCase
    private let sendMessageUseCase: SendMessageUseCase
    private let repository: MessagingRepositoryProtocol
    private let wsClient: MessagingWebSocketClient

    public init(
        currentUserId: UUID,
        fetchMessagesUseCase: FetchMessagesUseCase,
        sendMessageUseCase: SendMessageUseCase,
        repository: MessagingRepositoryProtocol,
        wsClient: MessagingWebSocketClient
    ) {
        self.currentUserId = currentUserId
        self.fetchMessagesUseCase = fetchMessagesUseCase
        self.sendMessageUseCase = sendMessageUseCase
        self.repository = repository
        self.wsClient = wsClient
    }

    @MainActor
    public func make(conversationId: UUID) -> ChatThreadViewModel {
        ChatThreadViewModel(
            conversationId: conversationId,
            fetchMessagesUseCase: fetchMessagesUseCase,
            sendMessageUseCase: sendMessageUseCase,
            repository: repository,
            wsClient: wsClient
        )
    }
}
