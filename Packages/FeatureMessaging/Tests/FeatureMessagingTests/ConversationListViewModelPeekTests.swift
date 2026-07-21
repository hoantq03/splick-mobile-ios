import XCTest
@testable import FeatureMessaging
import Common
import Localization
import SplickDomain
import Storage

private struct PeekSearchProviderStub: MessagingSearchProviding {
    func search(query: String) async throws -> [MessagingSearchResult] {
        []
    }
}

private actor PeekMessagingRepositoryStub: MessagingRepositoryProtocol {
    private let messagesByConversation: [UUID: [ChatMessage]]
    private let delayMillisecondsByConversation: [UUID: Int]
    private let shouldFailFetchingConversations: Bool

    init(
        messagesByConversation: [UUID: [ChatMessage]] = [:],
        delayMillisecondsByConversation: [UUID: Int] = [:],
        shouldFailFetchingConversations: Bool = false
    ) {
        self.messagesByConversation = messagesByConversation
        self.delayMillisecondsByConversation = delayMillisecondsByConversation
        self.shouldFailFetchingConversations = shouldFailFetchingConversations
    }

    func fetchConversations(query: ConversationInboxQuery) async throws -> [Conversation] {
        if shouldFailFetchingConversations {
            throw NetworkError.serverError(statusCode: 500, traceId: "support-reference")
        }
        return []
    }
    func fetchConversationInboxSummary() async throws -> Int { 0 }
    func getOrCreateConversation(friendUserId: UUID) async throws -> Conversation {
        makeConversation(id: UUID())
    }
    func createGroup(
        name: String,
        avatarUrl: String?,
        memberUserIds: [UUID],
        groupId: UUID?
    ) async throws -> Conversation {
        makeConversation(id: groupId ?? UUID())
    }
    func addGroupMember(groupId: UUID, memberUserId: UUID) async throws {}
    func removeGroupMember(groupId: UUID, memberUserId: UUID) async throws {}
    func leaveGroup(groupId: UUID) async throws {}
    func renameGroup(groupId: UUID, name: String) async throws -> Conversation {
        makeConversation(id: groupId)
    }
    func transferGroupAdmin(groupId: UUID, newAdminUserId: UUID) async throws {}
    func fetchMessages(conversationId: UUID, page: Int, limit: Int) async throws -> [ChatMessage] {
        if let delay = delayMillisecondsByConversation[conversationId], delay > 0 {
            try await Task.sleep(for: .milliseconds(delay))
        }
        return Array((messagesByConversation[conversationId] ?? []).prefix(limit))
    }
    func sendMessage(
        conversationId: UUID,
        body: String,
        clientMessageId: UUID,
        imageAttachments: [MessageImageAttachment],
        replyToMessageId: UUID?
    ) async throws -> ChatMessage {
        ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            senderId: UUID(),
            body: body,
            clientMessageId: clientMessageId,
            createdAt: .now,
            imageAttachments: imageAttachments
        )
    }
    func markRead(conversationId: UUID, upToMessageId: UUID) async throws {}
    func unreadCount() async throws -> Int { 0 }
    func addReaction(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction {
        Reaction(id: UUID(), emoji: emoji, userId: UUID(), createdAt: .now)
    }
    func removeReaction(conversationId: UUID, messageId: UUID, reactionId: UUID) async throws {}
    func searchMessages(query: String, page: Int, limit: Int) async throws -> [MessageSearchHit] { [] }

    private func makeConversation(id: UUID) -> Conversation {
        Conversation(
            id: id,
            unreadCount: 0,
            peer: nil,
            lastMessage: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }
}

@MainActor
final class ConversationListViewModelPeekTests: XCTestCase {
    private func makeViewModel(repository: PeekMessagingRepositoryStub) -> ConversationListViewModel {
        let languageService = LanguageService(userDefaults: UserDefaultsService())
        languageService.setLocale(.vi, persist: false)
        return ConversationListViewModel(
            fetchConversationsUseCase: FetchConversationsUseCase(repository: repository),
            fetchMessagesUseCase: FetchMessagesUseCase(repository: repository),
            searchProvider: PeekSearchProviderStub(),
            repository: repository,
            wsClient: MessagingWebSocketClient(tokenProvider: { nil }),
            languageService: languageService
        )
    }

    private func makeConversation(id: UUID = UUID()) -> Conversation {
        Conversation(
            id: id,
            unreadCount: 0,
            peer: nil,
            lastMessage: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeMessage(
        conversationId: UUID,
        body: String,
        createdAt: Date
    ) -> ChatMessage {
        ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            senderId: UUID(),
            body: body,
            clientMessageId: UUID(),
            createdAt: createdAt
        )
    }

    func test_beginPeek_loadsRecentMessagesInChronologicalOrder() async {
        let conversation = makeConversation()
        let older = makeMessage(
            conversationId: conversation.id,
            body: "Older",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let newer = makeMessage(
            conversationId: conversation.id,
            body: "Newer",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let repository = PeekMessagingRepositoryStub(
            messagesByConversation: [conversation.id: [newer, older]]
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.beginPeek(conversation: conversation)

        XCTAssertEqual(viewModel.peekConversation?.id, conversation.id)
        XCTAssertEqual(viewModel.peekMessages.map(\.body), ["Older", "Newer"])
        XCTAssertEqual(viewModel.peekLoadState, .loaded)
    }

    func test_dismissPeek_clearsPreviewState() async {
        let conversation = makeConversation()
        let repository = PeekMessagingRepositoryStub()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.beginPeek(conversation: conversation)

        viewModel.dismissPeek()

        XCTAssertNil(viewModel.peekConversation)
        XCTAssertTrue(viewModel.peekMessages.isEmpty)
        XCTAssertEqual(viewModel.peekLoadState, .idle)
    }

    func test_beginPeek_supersedesSlowerPreviousConversation() async {
        let firstConversation = makeConversation()
        let secondConversation = makeConversation()
        let firstMessage = makeMessage(
            conversationId: firstConversation.id,
            body: "First",
            createdAt: .now
        )
        let secondMessage = makeMessage(
            conversationId: secondConversation.id,
            body: "Second",
            createdAt: .now
        )
        let repository = PeekMessagingRepositoryStub(
            messagesByConversation: [
                firstConversation.id: [firstMessage],
                secondConversation.id: [secondMessage]
            ],
            delayMillisecondsByConversation: [firstConversation.id: 200]
        )
        let viewModel = makeViewModel(repository: repository)

        let firstLoad = Task {
            await viewModel.beginPeek(conversation: firstConversation)
        }
        try? await Task.sleep(for: .milliseconds(20))
        await viewModel.beginPeek(conversation: secondConversation)
        await firstLoad.value

        XCTAssertEqual(viewModel.peekConversation?.id, secondConversation.id)
        XCTAssertEqual(viewModel.peekMessages.map(\.body), ["Second"])
        XCTAssertEqual(viewModel.peekLoadState, .loaded)
    }

    func test_loadFailure_usesSelectedLanguageWithoutSupportReference() async {
        let repository = PeekMessagingRepositoryStub(shouldFailFetchingConversations: true)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        guard case .failed(let message) = viewModel.state else {
            return XCTFail("Expected failed state")
        }
        XCTAssertEqual(message, "Có gì đó hơi sai sai rồi. Thử lại phát nữa nhé!")
        XCTAssertFalse(message.contains("support-reference"))
        XCTAssertFalse(
            NetworkError.serverError(
                statusCode: 500,
                traceId: "support-reference"
            ).localizedDescription.contains("support-reference")
        )
    }
}
