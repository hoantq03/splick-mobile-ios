import SwiftUI
import Storage
import Localization
import SplickDomain

struct ChatThreadNavigationWrapper: View {
    let conversation: Conversation
    let highlightMessageId: UUID?

    @EnvironmentObject private var chatThreadViewModelFactory: ChatThreadViewModelFactory
    @Environment(\.chatPeerRelationshipActions) private var peerRelationshipActions

    init(conversation: Conversation, highlightMessageId: UUID? = nil) {
        self.conversation = conversation
        self.highlightMessageId = highlightMessageId
    }

    var body: some View {
        ChatThreadScreen(
            conversation: conversation,
            highlightMessageId: highlightMessageId,
            factory: chatThreadViewModelFactory,
            peerRelationshipActions: peerRelationshipActions
        )
    }
}

/// Holds a stable `ChatThreadViewModel` — must not create the VM in `body` or load() never completes after re-renders.
private struct ChatThreadScreen: View {
    let conversation: Conversation
    let highlightMessageId: UUID?
    let factory: ChatThreadViewModelFactory
    let peerRelationshipActions: ChatPeerRelationshipActions

    @StateObject private var viewModel: ChatThreadViewModel
    @StateObject private var relationshipViewModel: ChatPeerRelationshipViewModel

    init(
        conversation: Conversation,
        highlightMessageId: UUID?,
        factory: ChatThreadViewModelFactory,
        peerRelationshipActions: ChatPeerRelationshipActions
    ) {
        self.conversation = conversation
        self.highlightMessageId = highlightMessageId
        self.factory = factory
        self.peerRelationshipActions = peerRelationshipActions
        _viewModel = StateObject(
            wrappedValue: factory.make(
                conversationId: conversation.id,
                highlightMessageId: highlightMessageId
            )
        )
        if let peer = conversation.peer, !conversation.isGroup {
            _relationshipViewModel = StateObject(
                wrappedValue: ChatPeerRelationshipViewModel(
                    peerUserId: peer.userId,
                    actions: peerRelationshipActions
                )
            )
        } else {
            _relationshipViewModel = StateObject(wrappedValue: ChatPeerRelationshipViewModel.inert())
        }
    }

    var body: some View {
        ChatThreadView(
            viewModel: viewModel,
            relationshipViewModel: relationshipViewModel,
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
    private let uploadImage: (Data, String) async throws -> MessageImageAttachment
    private let wsClient: MessagingWebSocketClient
    private let languageService: LanguageService
    private let messageCache: MessageThreadCache
    private let onConversationRead: ((UUID) async -> Void)?

    public init(
        currentUserId: UUID,
        fetchMessagesUseCase: FetchMessagesUseCase,
        sendMessageUseCase: SendMessageUseCase,
        reactToMessageUseCase: ReactToMessageUseCaseProtocol,
        repository: MessagingRepositoryProtocol,
        uploadImage: @escaping (Data, String) async throws -> MessageImageAttachment,
        wsClient: MessagingWebSocketClient,
        languageService: LanguageService,
        messageCache: MessageThreadCache = MessageThreadCache(),
        onConversationRead: ((UUID) async -> Void)? = nil
    ) {
        self.currentUserId = currentUserId
        self.fetchMessagesUseCase = fetchMessagesUseCase
        self.sendMessageUseCase = sendMessageUseCase
        self.reactToMessageUseCase = reactToMessageUseCase
        self.repository = repository
        self.uploadImage = uploadImage
        self.wsClient = wsClient
        self.languageService = languageService
        self.messageCache = messageCache
        self.onConversationRead = onConversationRead
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
            uploadImage: uploadImage,
            wsClient: wsClient,
            languageService: languageService,
            messageCache: messageCache,
            onConversationRead: onConversationRead
        )
    }
}
