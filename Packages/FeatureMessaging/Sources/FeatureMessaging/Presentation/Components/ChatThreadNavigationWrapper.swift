import SwiftUI
import Storage
import SplickDomain

struct ChatThreadNavigationWrapper: View {
    let conversation: Conversation

    @EnvironmentObject private var chatThreadViewModelFactory: ChatThreadViewModelFactory

    var body: some View {
        ChatThreadScreen(
            conversation: conversation,
            factory: chatThreadViewModelFactory
        )
    }
}

/// Holds a stable `ChatThreadViewModel` — must not create the VM in `body` or load() never completes after re-renders.
private struct ChatThreadScreen: View {
    let conversation: Conversation
    let factory: ChatThreadViewModelFactory

    @StateObject private var viewModel: ChatThreadViewModel

    init(conversation: Conversation, factory: ChatThreadViewModelFactory) {
        self.conversation = conversation
        self.factory = factory
        _viewModel = StateObject(
            wrappedValue: factory.make(conversationId: conversation.id)
        )
    }

    var body: some View {
        ChatThreadView(
            viewModel: viewModel,
            currentUserId: factory.currentUserId,
            peer: conversation.peer,
            navigationTitle: conversation.peer?.displayTitle ?? ""
        )
    }
}

/// Factory injected via environment to create ChatThreadViewModel per conversation.
public final class ChatThreadViewModelFactory: ObservableObject {
    public let currentUserId: UUID
    private let fetchMessagesUseCase: FetchMessagesUseCase
    private let sendMessageUseCase: SendMessageUseCase
    private let reactToMessageUseCase: ReactToMessageUseCaseProtocol
    private let repository: MessagingRepositoryProtocol
    private let wsClient: MessagingWebSocketClient

    public init(
        currentUserId: UUID,
        fetchMessagesUseCase: FetchMessagesUseCase,
        sendMessageUseCase: SendMessageUseCase,
        reactToMessageUseCase: ReactToMessageUseCaseProtocol,
        repository: MessagingRepositoryProtocol,
        wsClient: MessagingWebSocketClient
    ) {
        self.currentUserId = currentUserId
        self.fetchMessagesUseCase = fetchMessagesUseCase
        self.sendMessageUseCase = sendMessageUseCase
        self.reactToMessageUseCase = reactToMessageUseCase
        self.repository = repository
        self.wsClient = wsClient
    }

    @MainActor
    public func make(conversationId: UUID) -> ChatThreadViewModel {
        ChatThreadViewModel(
            conversationId: conversationId,
            currentUserId: currentUserId,
            fetchMessagesUseCase: fetchMessagesUseCase,
            sendMessageUseCase: sendMessageUseCase,
            reactToMessageUseCase: reactToMessageUseCase,
            repository: repository,
            wsClient: wsClient
        )
    }
}
