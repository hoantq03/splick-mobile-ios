import SwiftUI
import Storage
import SplickDomain

struct ChatThreadNavigationWrapper: View {
    let conversation: Conversation
    let highlightMessageId: UUID?

    @EnvironmentObject private var chatThreadViewModelFactory: ChatThreadViewModelFactory

    init(conversation: Conversation, highlightMessageId: UUID? = nil) {
        self.conversation = conversation
        self.highlightMessageId = highlightMessageId
    }

    var body: some View {
        ChatThreadScreen(
            conversation: conversation,
            highlightMessageId: highlightMessageId,
            factory: chatThreadViewModelFactory
        )
    }
}

/// Holds a stable `ChatThreadViewModel` — must not create the VM in `body` or load() never completes after re-renders.
private struct ChatThreadScreen: View {
    let conversation: Conversation
    let highlightMessageId: UUID?
    let factory: ChatThreadViewModelFactory

    @StateObject private var viewModel: ChatThreadViewModel

    init(
        conversation: Conversation,
        highlightMessageId: UUID?,
        factory: ChatThreadViewModelFactory
    ) {
        self.conversation = conversation
        self.highlightMessageId = highlightMessageId
        self.factory = factory
        _viewModel = StateObject(
            wrappedValue: factory.make(
                conversationId: conversation.id,
                highlightMessageId: highlightMessageId
            )
        )
    }

    var body: some View {
        ChatThreadView(
            viewModel: viewModel,
            currentUserId: factory.currentUserId,
            peer: conversation.peer,
            navigationTitle: conversation.displayTitle,
            conversation: conversation,
            repository: factory.repository
        )
    }
}

/// Factory injected via environment to create ChatThreadViewModel per conversation.
public final class ChatThreadViewModelFactory: ObservableObject {
    public let currentUserId: UUID
    private let fetchMessagesUseCase: FetchMessagesUseCase
    private let sendMessageUseCase: SendMessageUseCase
    private let reactToMessageUseCase: ReactToMessageUseCaseProtocol
    public let repository: MessagingRepositoryProtocol
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
    public func make(conversationId: UUID, highlightMessageId: UUID? = nil) -> ChatThreadViewModel {
        ChatThreadViewModel(
            conversationId: conversationId,
            currentUserId: currentUserId,
            highlightMessageId: highlightMessageId,
            fetchMessagesUseCase: fetchMessagesUseCase,
            sendMessageUseCase: sendMessageUseCase,
            reactToMessageUseCase: reactToMessageUseCase,
            repository: repository,
            wsClient: wsClient
        )
    }
}
