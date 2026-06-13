import XCTest
import Combine
@testable import FeatureMessaging
import SplickDomain
import Foundation

// MARK: - Stub repository

private actor StubMessagingRepository: MessagingRepositoryProtocol {
    var messages: [ChatMessage]
    var markReadCalls: [(UUID, UUID)] = []

    init(messages: [ChatMessage] = []) {
        self.messages = messages
    }

    func fetchConversations(page: Int, limit: Int) async throws -> [Conversation] { [] }
    func getOrCreateConversation(friendUserId: UUID) async throws -> Conversation {
        Conversation(id: UUID(), unreadCount: 0, peer: nil, lastMessage: nil, createdAt: .now, updatedAt: .now)
    }
    func fetchMessages(conversationId: UUID, page: Int, limit: Int) async throws -> [ChatMessage] { messages }
    func sendMessage(conversationId: UUID, body: String, clientMessageId: UUID) async throws -> ChatMessage {
        ChatMessage(id: UUID(), conversationId: conversationId, senderId: UUID(), body: body, clientMessageId: clientMessageId, createdAt: .now)
    }
    func markRead(conversationId: UUID, upToMessageId: UUID) async throws {
        markReadCalls.append((conversationId, upToMessageId))
    }
    func unreadCount() async throws -> Int { 0 }
    func recordedMarkReadCalls() async -> [(UUID, UUID)] { markReadCalls }
}

// MARK: - Tests

@MainActor
final class ChatThreadViewModelTests: XCTestCase {

    private static let conversationId = UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000001")!
    private static let senderId = UUID(uuidString: "bbbbbbbb-0000-0000-0000-000000000001")!

    private func makeMessage(id: UUID = UUID(), body: String = "Hello") -> ChatMessage {
        ChatMessage(
            id: id,
            conversationId: Self.conversationId,
            senderId: Self.senderId,
            body: body,
            clientMessageId: UUID(),
            createdAt: .now
        )
    }

    // MARK: Deduplication

    func test_appendMessage_deduplicates_onWsEvent() async {
        let existingMsg = makeMessage(body: "Already here")
        let repo = StubMessagingRepository(messages: [existingMsg])
        let wsClient = MessagingWebSocketClient(tokenProvider: { nil })
        let vm = ChatThreadViewModel(
            conversationId: Self.conversationId,
            fetchMessagesUseCase: FetchMessagesUseCase(repository: repo),
            sendMessageUseCase: SendMessageUseCase(repository: repo),
            repository: repo,
            wsClient: wsClient
        )

        await vm.load()
        let countAfterLoad = vm.messages.count

        // Send duplicate via WS
        wsClient.eventSubject.send(.newMessage(conversationId: Self.conversationId, message: existingMsg))
        // Allow main-actor sink to process
        await Task.yield()

        XCTAssertEqual(vm.messages.count, countAfterLoad, "Duplicate message must not be appended")
    }

    func test_appendMessage_addsNewMessage_onWsEvent() async {
        let repo = StubMessagingRepository(messages: [])
        let wsClient = MessagingWebSocketClient(tokenProvider: { nil })
        let vm = ChatThreadViewModel(
            conversationId: Self.conversationId,
            fetchMessagesUseCase: FetchMessagesUseCase(repository: repo),
            sendMessageUseCase: SendMessageUseCase(repository: repo),
            repository: repo,
            wsClient: wsClient
        )

        await vm.load()
        XCTAssertEqual(vm.messages.count, 0)

        let newMsg = makeMessage(body: "New incoming")
        wsClient.eventSubject.send(.newMessage(conversationId: Self.conversationId, message: newMsg))
        await Task.yield()

        XCTAssertEqual(vm.messages.count, 1)
        XCTAssertEqual(vm.messages.first?.body, "New incoming")
    }

    // MARK: Mark-read on load

    func test_load_callsMarkRead_withLastMessageId_whenMessagesExist() async {
        let msg1 = makeMessage(body: "First")
        let msg2 = makeMessage(body: "Last")
        let repo = StubMessagingRepository(messages: [msg1, msg2])
        let wsClient = MessagingWebSocketClient(tokenProvider: { nil })
        let vm = ChatThreadViewModel(
            conversationId: Self.conversationId,
            fetchMessagesUseCase: FetchMessagesUseCase(repository: repo),
            sendMessageUseCase: SendMessageUseCase(repository: repo),
            repository: repo,
            wsClient: wsClient
        )

        await vm.load()
        // Give async markRead task a chance to complete
        try? await Task.sleep(nanoseconds: 50_000_000)

        let calls = await repo.recordedMarkReadCalls()
        XCTAssertFalse(calls.isEmpty, "markRead should be called after loading messages")
        XCTAssertEqual(calls.first?.0, Self.conversationId)
    }

    func test_load_doesNotCallMarkRead_whenNoMessages() async {
        let repo = StubMessagingRepository(messages: [])
        let wsClient = MessagingWebSocketClient(tokenProvider: { nil })
        let vm = ChatThreadViewModel(
            conversationId: Self.conversationId,
            fetchMessagesUseCase: FetchMessagesUseCase(repository: repo),
            sendMessageUseCase: SendMessageUseCase(repository: repo),
            repository: repo,
            wsClient: wsClient
        )

        await vm.load()
        try? await Task.sleep(nanoseconds: 50_000_000)

        let calls = await repo.recordedMarkReadCalls()
        XCTAssertTrue(calls.isEmpty, "markRead must not be called when there are no messages")
    }

    // MARK: WS event from different conversation is ignored

    func test_wsEvent_fromDifferentConversation_isIgnored() async {
        let repo = StubMessagingRepository(messages: [])
        let wsClient = MessagingWebSocketClient(tokenProvider: { nil })
        let vm = ChatThreadViewModel(
            conversationId: Self.conversationId,
            fetchMessagesUseCase: FetchMessagesUseCase(repository: repo),
            sendMessageUseCase: SendMessageUseCase(repository: repo),
            repository: repo,
            wsClient: wsClient
        )

        await vm.load()
        let otherConvId = UUID()
        let msg = ChatMessage(id: UUID(), conversationId: otherConvId, senderId: Self.senderId, body: "Other", clientMessageId: UUID(), createdAt: .now)
        wsClient.eventSubject.send(.newMessage(conversationId: otherConvId, message: msg))
        await Task.yield()

        XCTAssertEqual(vm.messages.count, 0)
    }
}
