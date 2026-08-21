import XCTest
import Combine
@testable import FeatureMessaging
import Localization
import Storage
import SplickDomain
import Foundation

// MARK: - Stub repository

private actor StubMessagingRepository: MessagingRepositoryProtocol {
    var messages: [ChatMessage]
    var markReadCalls: [(UUID, UUID)] = []
    private(set) var sendMessageCallCount = 0
    private(set) var afterFetchCalls: [Int64] = []

    init(messages: [ChatMessage] = []) {
        self.messages = messages
    }

    func fetchConversations(query: ConversationInboxQuery) async throws -> MessagingPage<Conversation> {
        MessagingPage(items: [], hasMore: false)
    }
    func fetchConversationInboxSummary() async throws -> Int { 0 }
    func getOrCreateConversation(friendUserId: UUID) async throws -> Conversation {
        Conversation(id: UUID(), unreadCount: 0, peer: nil, lastMessage: nil, createdAt: .now, updatedAt: .now)
    }
    func createGroup(
        name: String,
        avatarUrl: String?,
        memberUserIds: [UUID],
        groupId: UUID?
    ) async throws -> Conversation {
        Conversation(
            id: groupId ?? UUID(),
            type: .group,
            unreadCount: 0,
            peer: nil,
            groupName: name,
            lastMessage: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }
    func addGroupMember(groupId: UUID, memberUserId: UUID) async throws {}
    func removeGroupMember(groupId: UUID, memberUserId: UUID) async throws {}
    func leaveGroup(groupId: UUID) async throws {}
    func deleteConversation(conversationId: UUID) async throws {}
    func updateNotificationSettings(
        conversationId: UUID,
        notificationsEnabled: Bool,
        notificationSound: String
    ) async throws -> Conversation {
        Conversation(
            id: conversationId,
            unreadCount: 0,
            peer: nil,
            lastMessage: nil,
            createdAt: .now,
            updatedAt: .now,
            notificationsEnabled: notificationsEnabled,
            notificationSound: notificationSound
        )
    }
    func renameGroup(groupId: UUID, name: String) async throws -> Conversation {
        Conversation(id: groupId, unreadCount: 0, peer: nil, lastMessage: nil, createdAt: .now, updatedAt: .now)
    }
    func transferGroupAdmin(groupId: UUID, newAdminUserId: UUID) async throws {}
    func fetchMessages(
        conversationId: UUID,
        page: Int,
        limit: Int,
        after: Int64?,
        before: Int64?
    ) async throws -> MessagingPage<ChatMessage> {
        if let after {
            afterFetchCalls.append(after)
            let gap = messages.filter { $0.sequenceNo > after }.sorted { $0.sequenceNo < $1.sequenceNo }
            return MessagingPage(items: gap, hasMore: false)
        }
        // API order: newest first.
        let start = page * limit
        guard start < messages.count else { return MessagingPage(items: [], hasMore: false) }
        let end = min(start + limit, messages.count)
        let slice = Array(messages[start..<end])
        return MessagingPage(items: slice, hasMore: end < messages.count)
    }
    func sendMessage(
        conversationId: UUID,
        body: String,
        clientMessageId: UUID,
        imageAttachments: [MessageImageAttachment],
        replyToMessageId: UUID? = nil
    ) async throws -> ChatMessage {
        sendMessageCallCount += 1
        return ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            senderId: ChatThreadViewModelTestFixtures.currentUserId,
            body: body,
            clientMessageId: clientMessageId,
            createdAt: .now,
            sequenceNo: 1,
            imageAttachments: imageAttachments
        )
    }
    func markRead(conversationId: UUID, upToMessageId: UUID) async throws {
        markReadCalls.append((conversationId, upToMessageId))
    }
    func unreadCount() async throws -> Int { 0 }
    func addReaction(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction {
        Reaction(id: UUID(), emoji: emoji, userId: UUID(), createdAt: .now)
    }
    func removeReaction(conversationId: UUID, messageId: UUID, reactionId: UUID) async throws {}
    func searchMessages(query: String, page: Int, limit: Int, conversationId: UUID?) async throws -> [MessageSearchHit] { [] }
    func requestWsTicket() async throws -> String { "test-ticket" }
    func recordedMarkReadCalls() async -> [(UUID, UUID)] { markReadCalls }
    func recordedSendMessageCallCount() async -> Int { sendMessageCallCount }
}

private struct StubReactToMessageUseCase: ReactToMessageUseCaseProtocol {
    func execute(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction {
        Reaction(id: UUID(), emoji: emoji, userId: UUID(), createdAt: .now)
    }
}

// MARK: - Test fixtures

private enum ChatThreadViewModelTestFixtures {
    static let conversationId = UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000001")!
    static let senderId = UUID(uuidString: "bbbbbbbb-0000-0000-0000-000000000001")!
    static let currentUserId = UUID(uuidString: "cccccccc-0000-0000-0000-000000000001")!
}

@MainActor
private func makeTestWsClient() -> MessagingWebSocketClient {
    MessagingWebSocketClient(
        ticketProvider: { "ticket" },
        deviceIdProvider: { "device" }
    )
}

// MARK: - Tests

@MainActor
final class ChatThreadViewModelTests: XCTestCase {

    private func makeViewModel(
        conversationId: UUID = ChatThreadViewModelTestFixtures.conversationId,
        highlightMessageId: UUID? = nil,
        repo: StubMessagingRepository,
        wsClient: MessagingWebSocketClient,
        pendingStore: PendingMessageStore? = nil
    ) -> ChatThreadViewModel {
        ChatThreadViewModel(
            conversationId: conversationId,
            currentUserId: ChatThreadViewModelTestFixtures.currentUserId,
            highlightMessageId: highlightMessageId,
            fetchMessagesUseCase: FetchMessagesUseCase(repository: repo),
            sendMessageUseCase: SendMessageUseCase(repository: repo),
            reactToMessageUseCase: StubReactToMessageUseCase(),
            repository: repo,
            uploadImage: { _, _ in
                MessageImageAttachment(
                    mediaId: UUID(),
                    url: URL(string: "https://example.com/image.jpg")!,
                    thumbnailURL: nil
                )
            },
            wsClient: wsClient,
            languageService: LanguageService(userDefaults: UserDefaultsService()),
            pendingMessageStore: pendingStore
        )
    }

    private func makeMessage(
        id: UUID = UUID(),
        body: String = "Hello",
        sequenceNo: Int64 = 0
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            conversationId: ChatThreadViewModelTestFixtures.conversationId,
            senderId: ChatThreadViewModelTestFixtures.senderId,
            body: body,
            clientMessageId: UUID(),
            createdAt: .now,
            sequenceNo: sequenceNo
        )
    }

    func test_send_withMultipleImages_makesSingleRepositoryCall() async {
        let repo = StubMessagingRepository(messages: [])
        let wsClient = makeTestWsClient()
        let vm = makeViewModel(repo: repo, wsClient: wsClient)

        await vm.load()

        let submissions = (0..<3).map { index in
            CommentSubmissionAttachment(
                kind: .image,
                uploadedMediaId: UUID(),
                url: URL(string: "https://example.com/\(index).jpg")!,
                sizeBytes: 1024,
                fileName: "photo-\(index).jpg"
            )
        }

        await vm.send(body: "Album", submissions: submissions)

        let sendCount = await repo.recordedSendMessageCallCount()
        XCTAssertEqual(sendCount, 1)
        XCTAssertEqual(vm.messages.count, 1)
        XCTAssertEqual(vm.messages.first?.imageAttachments.count, 3)
    }

    // MARK: Deduplication

    func test_appendMessage_deduplicates_onWsEvent() async {
        let existingMsg = makeMessage(body: "Already here")
        let repo = StubMessagingRepository(messages: [existingMsg])
        let wsClient = makeTestWsClient()
        let vm = makeViewModel(repo: repo, wsClient: wsClient)

        await vm.load()
        let countAfterLoad = vm.messages.count

        // Send duplicate via WS
        wsClient.eventSubject.send(.newMessage(conversationId: ChatThreadViewModelTestFixtures.conversationId, message: existingMsg))
        // Allow main-actor sink to process
        await Task.yield()

        XCTAssertEqual(vm.messages.count, countAfterLoad, "Duplicate message must not be appended")
    }

    func test_appendMessage_addsNewMessage_onWsEvent() async {
        let repo = StubMessagingRepository(messages: [])
        let wsClient = makeTestWsClient()
        let vm = makeViewModel(repo: repo, wsClient: wsClient)

        await vm.load()
        XCTAssertEqual(vm.messages.count, 0)

        let newMsg = makeMessage(body: "New incoming", sequenceNo: 5)
        wsClient.eventSubject.send(.newMessage(conversationId: ChatThreadViewModelTestFixtures.conversationId, message: newMsg))
        await Task.yield()

        XCTAssertEqual(vm.messages.count, 1)
        XCTAssertEqual(vm.messages.first?.body, "New incoming")
        XCTAssertEqual(vm.messages.first?.sequenceNo, 5)
    }

    // MARK: Mark-read on load

    func test_load_callsMarkRead_withLastMessageId_whenMessagesExist() async {
        let msg1 = makeMessage(body: "First", sequenceNo: 1)
        let msg2 = makeMessage(body: "Last", sequenceNo: 2)
        let repo = StubMessagingRepository(messages: [msg1, msg2])
        let wsClient = makeTestWsClient()
        let vm = makeViewModel(repo: repo, wsClient: wsClient)
        vm.isNearBottom = true

        await vm.load()
        // Debounced markRead (500ms)
        try? await Task.sleep(nanoseconds: 700_000_000)

        let calls = await repo.recordedMarkReadCalls()
        XCTAssertFalse(calls.isEmpty, "markRead should be called after loading messages")
        XCTAssertEqual(calls.first?.0, ChatThreadViewModelTestFixtures.conversationId)
    }

    func test_load_doesNotCallMarkRead_whenNoMessages() async {
        let repo = StubMessagingRepository(messages: [])
        let wsClient = makeTestWsClient()
        let vm = makeViewModel(repo: repo, wsClient: wsClient)

        await vm.load()
        try? await Task.sleep(nanoseconds: 700_000_000)

        let calls = await repo.recordedMarkReadCalls()
        XCTAssertTrue(calls.isEmpty, "markRead must not be called when there are no messages")
    }

    func test_load_marksRead_evenWhenNotNearBottom() async {
        let msg = makeMessage(body: "Only", sequenceNo: 1)
        let repo = StubMessagingRepository(messages: [msg])
        let wsClient = makeTestWsClient()
        let vm = makeViewModel(repo: repo, wsClient: wsClient)
        vm.isNearBottom = false

        await vm.load()
        try? await Task.sleep(nanoseconds: 700_000_000)

        let calls = await repo.recordedMarkReadCalls()
        XCTAssertFalse(calls.isEmpty, "Opening a chat should mark read even when not near bottom")
        XCTAssertEqual(calls.first?.1, msg.id)
    }

    func test_wsNewMessage_skipsMarkReadWhenNotNearBottom() async {
        let existing = makeMessage(body: "Existing", sequenceNo: 1)
        let repo = StubMessagingRepository(messages: [existing])
        let wsClient = makeTestWsClient()
        let vm = makeViewModel(repo: repo, wsClient: wsClient)
        await vm.load()
        try? await Task.sleep(nanoseconds: 700_000_000)
        let callsAfterLoad = await repo.recordedMarkReadCalls()
        let baseline = callsAfterLoad.count

        vm.isNearBottom = false
        let incoming = ChatMessage(
            id: UUID(),
            conversationId: ChatThreadViewModelTestFixtures.conversationId,
            senderId: ChatThreadViewModelTestFixtures.senderId,
            body: "While scrolled up",
            clientMessageId: UUID(),
            createdAt: .now,
            sequenceNo: 2
        )
        wsClient.eventSubject.send(
            .newMessage(
                conversationId: ChatThreadViewModelTestFixtures.conversationId,
                message: incoming
            )
        )
        try? await Task.sleep(nanoseconds: 700_000_000)

        let calls = await repo.recordedMarkReadCalls()
        XCTAssertEqual(calls.count, baseline, "Incoming while scrolled up must not advance read cursor")
    }

    func test_deliveryAck_cascadesOlderOutgoingMessages() async {
        let olderId = UUID()
        let newerId = UUID()
        let older = ChatMessage(
            id: olderId,
            conversationId: ChatThreadViewModelTestFixtures.conversationId,
            senderId: ChatThreadViewModelTestFixtures.currentUserId,
            body: "Older",
            clientMessageId: olderId,
            createdAt: Date(timeIntervalSince1970: 1),
            sequenceNo: 1,
            deliveryStatus: .sent
        )
        let newer = ChatMessage(
            id: newerId,
            conversationId: ChatThreadViewModelTestFixtures.conversationId,
            senderId: ChatThreadViewModelTestFixtures.currentUserId,
            body: "Newer",
            clientMessageId: newerId,
            createdAt: Date(timeIntervalSince1970: 2),
            sequenceNo: 2,
            deliveryStatus: .sent
        )
        // API order newest-first for page 0.
        let repo = StubMessagingRepository(messages: [newer, older])
        let wsClient = makeTestWsClient()
        let vm = makeViewModel(repo: repo, wsClient: wsClient)
        await vm.load()

        wsClient.eventSubject.send(
            .deliveryAck(
                conversationId: ChatThreadViewModelTestFixtures.conversationId,
                messageId: newerId
            )
        )
        await Task.yield()

        XCTAssertEqual(vm.messages.first(where: { $0.id == olderId })?.deliveryStatus, .delivered)
        XCTAssertEqual(vm.messages.first(where: { $0.id == newerId })?.deliveryStatus, .delivered)
    }

    // MARK: WS event from different conversation is ignored

    func test_wsEvent_fromDifferentConversation_isIgnored() async {
        let repo = StubMessagingRepository(messages: [])
        let wsClient = makeTestWsClient()
        let vm = makeViewModel(repo: repo, wsClient: wsClient)

        await vm.load()
        let otherConvId = UUID()
        let msg = ChatMessage(
            id: UUID(),
            conversationId: otherConvId,
            senderId: ChatThreadViewModelTestFixtures.senderId,
            body: "Other",
            clientMessageId: UUID(),
            createdAt: .now
        )
        wsClient.eventSubject.send(.newMessage(conversationId: otherConvId, message: msg))
        await Task.yield()

        XCTAssertEqual(vm.messages.count, 0)
    }

    func test_loadWithHighlightMessage_setsHighlightAndScrollToken() async {
        let targetId = UUID()
        let targetMessage = makeMessage(id: targetId, body: "Find me")
        let repo = StubMessagingRepository(messages: [targetMessage])
        let wsClient = makeTestWsClient()
        let vm = makeViewModel(highlightMessageId: targetId, repo: repo, wsClient: wsClient)

        await vm.load()

        XCTAssertEqual(vm.messages.first?.id, targetId)
        XCTAssertEqual(vm.highlightedMessageId, targetId)
        XCTAssertGreaterThan(vm.scrollToMessageToken, 0)
    }

    // MARK: Pagination

    func test_loadOlderMessages_prependsUniqueOlderPage() async {
        var newestFirst: [ChatMessage] = []
        for index in 0..<40 {
            let created = Date(timeIntervalSince1970: TimeInterval(1_700_000_000 - index))
            newestFirst.append(
                ChatMessage(
                    id: UUID(uuidString: String(format: "dddddddd-0000-0000-0000-%012d", index))!,
                    conversationId: ChatThreadViewModelTestFixtures.conversationId,
                    senderId: ChatThreadViewModelTestFixtures.senderId,
                    body: "msg-\(index)",
                    clientMessageId: UUID(uuidString: String(format: "eeeeeeee-0000-0000-0000-%012d", index))!,
                    createdAt: created,
                    sequenceNo: Int64(40 - index)
                )
            )
        }

        let repo = StubMessagingRepository(messages: newestFirst)
        let wsClient = makeTestWsClient()
        let vm = makeViewModel(repo: repo, wsClient: wsClient)

        await vm.load()
        XCTAssertEqual(vm.messages.count, 30)
        XCTAssertTrue(vm.hasMoreMessages)
        let firstAfterLoad = vm.messages.first!

        await vm.loadOlderMessagesIfNeeded(current: firstAfterLoad)

        XCTAssertEqual(vm.messages.count, 40)
        XCTAssertFalse(vm.hasMoreMessages)
        XCTAssertEqual(vm.messages.first?.body, "msg-39")
        XCTAssertEqual(vm.prependAnchorMessageId, firstAfterLoad.clientMessageId)
    }

    func test_loadOlderMessages_ignoredWhenNotAtTop() async {
        let page = (0..<30).map { index in
            ChatMessage(
                id: UUID(),
                conversationId: ChatThreadViewModelTestFixtures.conversationId,
                senderId: ChatThreadViewModelTestFixtures.senderId,
                body: "msg-\(index)",
                clientMessageId: UUID(),
                createdAt: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 - index)),
                sequenceNo: Int64(30 - index)
            )
        }
        let repo = StubMessagingRepository(messages: page)
        let wsClient = makeTestWsClient()
        let vm = makeViewModel(repo: repo, wsClient: wsClient)

        await vm.load()
        guard let notFirst = vm.messages.last else {
            return XCTFail("Expected messages")
        }
        await vm.loadOlderMessagesIfNeeded(current: notFirst)
        XCTAssertEqual(vm.messages.count, 30)
    }

    // MARK: Cache

    func test_load_paintsCachedMessagesThenReconciles() async {
        let cachedMessage = makeMessage(body: "Cached")
        let freshMessage = makeMessage(body: "Fresh")
        let cache = MessageThreadCache(capacity: 5)
        cache.store(
            conversationId: ChatThreadViewModelTestFixtures.conversationId,
            messages: [cachedMessage],
            highestLoadedPage: 0,
            hasMoreMessages: false
        )

        let repo = StubMessagingRepository(messages: [freshMessage])
        let wsClient = makeTestWsClient()
        let vm = ChatThreadViewModel(
            conversationId: ChatThreadViewModelTestFixtures.conversationId,
            currentUserId: ChatThreadViewModelTestFixtures.currentUserId,
            fetchMessagesUseCase: FetchMessagesUseCase(repository: repo),
            sendMessageUseCase: SendMessageUseCase(repository: repo),
            reactToMessageUseCase: StubReactToMessageUseCase(),
            repository: repo,
            uploadImage: { _, _ in
                MessageImageAttachment(
                    mediaId: UUID(),
                    url: URL(string: "https://example.com/image.jpg")!,
                    thumbnailURL: nil
                )
            },
            wsClient: wsClient,
            languageService: LanguageService(userDefaults: UserDefaultsService()),
            messageCache: cache
        )

        await vm.load()

        XCTAssertEqual(vm.messages.count, 1)
        XCTAssertEqual(vm.messages.first?.body, "Fresh")
        XCTAssertEqual(cache.entry(for: ChatThreadViewModelTestFixtures.conversationId)?.messages.first?.body, "Fresh")
    }
}
