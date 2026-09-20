import XCTest
@testable import FeatureMessaging
import Common
import Localization
import SplickDomain
import Storage

private final class ComprehensiveUserDefaultsMock: UserDefaultsServiceProtocol, @unchecked Sendable {
    private var storage: [String: Any] = [:]
    func set<T: Codable>(_ value: T, for key: String) { storage[key] = try? JSONEncoder().encode(value) }
    func get<T: Codable>(for key: String) -> T? {
        guard let data = storage[key] as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    func setBool(_ value: Bool, for key: String) { storage[key] = value }
    func getBool(for key: String) -> Bool { storage[key] as? Bool ?? false }
    func remove(for key: String) { storage.removeValue(forKey: key) }
}

private actor ComprehensiveMessagingRepositoryStub: MessagingRepositoryProtocol {
    var fetchConversationsResult: Result<MessagingPage<Conversation>, Error> = .success(MessagingPage(items: [], hasMore: false))
    var fetchInboxSummaryResult: Result<Int, Error> = .success(0)
    var getOrCreateResult: Result<Conversation, Error> = .success(Conversation(id: UUID(), unreadCount: 0, peer: nil, lastMessage: nil, createdAt: .now, updatedAt: .now))
    var deleteResult: Result<Void, Error> = .success(())
    var fetchMessagesResult: Result<MessagingPage<ChatMessage>, Error> = .success(MessagingPage(items: [], hasMore: false))

    var lastQuery: ConversationInboxQuery?
    var deletedConversationIds: [UUID] = []
    var markReadCalls: [(UUID, UUID)] = []

    func setFetchConversationsResult(_ result: Result<MessagingPage<Conversation>, Error>) {
        fetchConversationsResult = result
    }

    func setFetchInboxSummaryResult(_ result: Result<Int, Error>) {
        fetchInboxSummaryResult = result
    }

    func setGetOrCreateResult(_ result: Result<Conversation, Error>) {
        getOrCreateResult = result
    }

    func setDeleteResult(_ result: Result<Void, Error>) {
        deleteResult = result
    }

    func setFetchMessagesResult(_ result: Result<MessagingPage<ChatMessage>, Error>) {
        fetchMessagesResult = result
    }

    func fetchConversations(query: ConversationInboxQuery) async throws -> MessagingPage<Conversation> {
        lastQuery = query
        return try fetchConversationsResult.get()
    }

    func fetchConversationInboxSummary() async throws -> Int {
        try fetchInboxSummaryResult.get()
    }

    func getOrCreateConversation(friendUserId: UUID) async throws -> Conversation {
        try getOrCreateResult.get()
    }

    func createGroup(
        name: String,
        avatarUrl: String?,
        memberUserIds: [UUID],
        groupId: UUID?
    ) async throws -> Conversation {
        Conversation(id: groupId ?? UUID(), type: .group, unreadCount: 0, peer: nil, groupName: name, lastMessage: nil, createdAt: .now, updatedAt: .now)
    }

    func addGroupMember(groupId: UUID, memberUserId: UUID, shareChatHistory: Bool) async throws {}
    func listGroupMembers(groupId: UUID) async throws -> [GroupChatMember] { [] }
    func removeGroupMember(groupId: UUID, memberUserId: UUID) async throws {}
    func leaveGroup(groupId: UUID) async throws {}

    func deleteConversation(conversationId: UUID) async throws {
        deletedConversationIds.append(conversationId)
        try deleteResult.get()
    }

    func updateNotificationSettings(
        conversationId: UUID,
        notificationsEnabled: Bool,
        notificationSound: String,
        mutedUntil: Date?
    ) async throws -> Conversation {
        Conversation(
            id: conversationId,
            unreadCount: 0,
            peer: nil,
            lastMessage: nil,
            createdAt: .now,
            updatedAt: .now,
            notificationsEnabled: notificationsEnabled,
            notificationSound: notificationSound,
            mutedUntil: mutedUntil
        )
    }

    func renameGroup(groupId: UUID, name: String) async throws -> Conversation {
        Conversation(id: groupId, unreadCount: 0, peer: nil, lastMessage: nil, createdAt: .now, updatedAt: .now)
    }

    func updateGroupAvatar(groupId: UUID, avatarUrl: String) async throws -> Conversation {
        Conversation(id: groupId, unreadCount: 0, peer: nil, groupAvatarUrl: avatarUrl, lastMessage: nil, createdAt: .now, updatedAt: .now)
    }

    func transferGroupAdmin(groupId: UUID, newAdminUserId: UUID) async throws {}

    func fetchMessages(
        conversationId: UUID,
        page: Int,
        limit: Int,
        after: Int64?,
        before: Int64?
    ) async throws -> MessagingPage<ChatMessage> {
        try fetchMessagesResult.get()
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

    func markRead(conversationId: UUID, upToMessageId: UUID) async throws {
        markReadCalls.append((conversationId, upToMessageId))
    }

    func unreadCount() async throws -> Int { 0 }
    func addReaction(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction {
        Reaction(id: UUID(), emoji: emoji, userId: UUID(), createdAt: .now)
    }
    func removeReaction(conversationId: UUID, messageId: UUID, reactionId: UUID) async throws {}
    func searchMessages(query: String, page: Int, limit: Int, conversationId: UUID?) async throws -> [MessageSearchHit] { [] }

    func editMessage(conversationId: UUID, messageId: UUID, body: String) async throws -> ChatMessage {
        ChatMessage(
            id: messageId,
            conversationId: conversationId,
            senderId: UUID(),
            body: body,
            clientMessageId: UUID(),
            createdAt: Date(),
            editedAt: Date()
        )
    }

    func recallMessage(conversationId: UUID, messageId: UUID) async throws {}
    func requestWsTicket() async throws -> String { "ticket" }
}

private final class ComprehensiveSearchProviderStub: MessagingSearchProviding, @unchecked Sendable {
    var searchResult: Result<[MessagingSearchResult], Error> = .success([])
    var lastSearchQuery: String?

    func search(query: String) async throws -> [MessagingSearchResult] {
        lastSearchQuery = query
        return try searchResult.get()
    }
}

@MainActor
final class ConversationListViewModelComprehensiveTests: XCTestCase {

    private func makeViewModel(
        repository: ComprehensiveMessagingRepositoryStub = ComprehensiveMessagingRepositoryStub(),
        searchProvider: ComprehensiveSearchProviderStub = ComprehensiveSearchProviderStub(),
        messageCache: MessageThreadCache? = nil,
        onInboxLoaded: (([Conversation], Int) async -> Void)? = nil
    ) -> (ConversationListViewModel, MessagingWebSocketClient, ComprehensiveMessagingRepositoryStub, ComprehensiveSearchProviderStub) {
        let languageService = LanguageService(userDefaults: ComprehensiveUserDefaultsMock())
        let wsClient = MessagingWebSocketClient(
            ticketProvider: { "ticket" },
            deviceIdProvider: { "device" }
        )
        let vm = ConversationListViewModel(
            fetchConversationsUseCase: FetchConversationsUseCase(repository: repository),
            fetchMessagesUseCase: FetchMessagesUseCase(repository: repository),
            searchProvider: searchProvider,
            repository: repository,
            wsClient: wsClient,
            languageService: languageService,
            messageCache: messageCache,
            onInboxLoaded: onInboxLoaded
        )
        return (vm, wsClient, repository, searchProvider)
    }

    private func makeTestConversation(
        id: UUID = UUID(),
        type: ConversationType = .direct,
        unreadCount: Int = 0,
        groupName: String? = nil,
        lastMessage: ChatMessage? = nil,
        leftAt: Date? = nil
    ) -> Conversation {
        Conversation(
            id: id,
            type: type,
            unreadCount: unreadCount,
            peer: type == .direct ? ConversationPeer(userId: UUID(), username: "peer", displayName: "Peer", avatarUrl: nil) : nil,
            groupName: groupName,
            groupAvatarUrl: nil,
            memberCount: type == .group ? 5 : nil,
            lastMessage: lastMessage,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200),
            notificationsEnabled: true,
            notificationSound: "default",
            mutedUntil: nil,
            leftAt: leftAt
        )
    }

    // MARK: - Filter Tests

    func testFilterTogglingAndChecking() async {
        let (vm, _, repo, _) = makeViewModel()

        XCTAssertNil(vm.activeFilter)
        XCTAssertFalse(vm.isFilterActive(.groups))
        XCTAssertFalse(vm.isFilterActive(.users))
        XCTAssertFalse(vm.isFilterActive(.unread))
        XCTAssertFalse(vm.isFilterActive(.closeFriends))

        // Toggle .groups
        vm.toggleFilter(.groups)
        XCTAssertEqual(vm.activeFilter, .groups)
        XCTAssertTrue(vm.isFilterActive(.groups))
        try? await Task.sleep(for: .milliseconds(80))
        var lastQuery = await repo.lastQuery
        XCTAssertEqual(lastQuery?.type, .group)

        // Toggle .groups again -> turns off
        vm.toggleFilter(.groups)
        XCTAssertNil(vm.activeFilter)
        XCTAssertFalse(vm.isFilterActive(.groups))
        try? await Task.sleep(for: .milliseconds(80))

        // Toggle .users
        vm.toggleFilter(.users)
        XCTAssertEqual(vm.activeFilter, .users)
        XCTAssertTrue(vm.isFilterActive(.users))
        try? await Task.sleep(for: .milliseconds(80))
        lastQuery = await repo.lastQuery
        XCTAssertEqual(lastQuery?.type, .direct)

        // Toggle .unread
        vm.toggleFilter(.unread)
        XCTAssertEqual(vm.activeFilter, .unread)
        XCTAssertTrue(vm.isFilterActive(.unread))
        try? await Task.sleep(for: .milliseconds(80))
        lastQuery = await repo.lastQuery
        XCTAssertEqual(lastQuery?.unreadOnly, true)

        // Toggle .closeFriends -> guard prevents action
        vm.toggleFilter(.closeFriends)
        XCTAssertEqual(vm.activeFilter, .unread)
    }

    // MARK: - Active Conversation Tracking

    func testActiveConversationTracking() {
        let (vm, _, _, _) = makeViewModel()
        let c1 = makeTestConversation(unreadCount: 3)
        vm.applyStartupConversations([c1])

        XCTAssertNil(vm.activeConversationId)

        // Set active conversation marks read
        vm.setActiveConversation(c1.id)
        XCTAssertEqual(vm.activeConversationId, c1.id)
        XCTAssertEqual(vm.conversations.first?.unreadCount, 0)

        // Clear non-matching ID does not clear active conversation
        let otherId = UUID()
        vm.clearActiveConversation(otherId)
        XCTAssertEqual(vm.activeConversationId, c1.id)

        // Clear matching ID clears active conversation
        vm.clearActiveConversation(c1.id)
        XCTAssertNil(vm.activeConversationId)
    }

    // MARK: - Startup and Load Tests

    func testStartupConversationsAndLoad() async {
        let (vm, _, repo, _) = makeViewModel()

        // Empty startup does nothing
        vm.applyStartupConversations([])
        XCTAssertTrue(vm.conversations.isEmpty)
        guard case .idle = vm.state else { return XCTFail("Expected idle") }

        // Non-empty startup sets state and pagination
        let c1 = makeTestConversation()
        vm.applyStartupConversations([c1])
        XCTAssertEqual(vm.conversations.count, 1)
        XCTAssertFalse(vm.hasMorePages)

        // When already loaded, load() skips
        await vm.load()
        var lastQuery = await repo.lastQuery
        XCTAssertNil(lastQuery)

        // Create new VM in idle state and load
        let (vm2, _, repo2, _) = makeViewModel()
        await repo2.setFetchConversationsResult(.success(MessagingPage(items: [c1], hasMore: false)))
        await repo2.setFetchInboxSummaryResult(.success(5))
        await vm2.load()

        lastQuery = await repo2.lastQuery
        XCTAssertNotNil(lastQuery)
        XCTAssertEqual(vm2.conversations.count, 1)
        XCTAssertEqual(vm2.unreadConversationCount, 5)
    }

    func testLoadFailureSetsErrorState() async {
        let (vm, _, repo, _) = makeViewModel()
        await repo.setFetchConversationsResult(.failure(NetworkError.serverError(statusCode: 500, traceId: "test")))
        await vm.load()

        guard case .failed = vm.state else {
            return XCTFail("Expected failed state on error")
        }
    }

    // MARK: - Refresh and Queued Refresh

    func testRefreshFlow() async {
        var onLoadedCount = 0
        let (vm, _, repo, _) = makeViewModel(onInboxLoaded: { _, _ in
            onLoadedCount += 1
        })
        let c1 = makeTestConversation()
        await repo.setFetchConversationsResult(.success(MessagingPage(items: [c1], hasMore: false)))

        await vm.refresh()
        XCTAssertEqual(vm.conversations.count, 1)
        XCTAssertEqual(onLoadedCount, 1)

        // Second refresh calls onInboxLoaded again
        await vm.refresh()
        XCTAssertEqual(onLoadedCount, 2)
    }

    // MARK: - Load More Tests

    func testLoadMoreFlow() async {
        let (vm, _, repo, _) = makeViewModel()
        let c1 = makeTestConversation()
        let c2 = makeTestConversation()

        // 20 items to simulate hasMorePages = true
        var items: [Conversation] = []
        for _ in 0..<20 {
            items.append(makeTestConversation())
        }
        vm.applyStartupConversations(items)
        XCTAssertTrue(vm.hasMorePages)

        // If current is not last, loadMore is a no-op
        await vm.loadMoreIfNeeded(current: c1)

        // When current is last, loadMore performs pagination
        await repo.setFetchConversationsResult(.success(MessagingPage(items: [c2], hasMore: false)))
        await vm.loadMoreIfNeeded(current: items.last!)
        XCTAssertEqual(vm.conversations.count, 21)
        XCTAssertFalse(vm.hasMorePages)

        // Empty next page sets hasMorePages to false
        vm.applyStartupConversations(items)
        await repo.setFetchConversationsResult(.success(MessagingPage(items: [], hasMore: false)))
        await vm.loadMoreIfNeeded(current: items.last!)
        XCTAssertFalse(vm.hasMorePages)

        // Error in load more is handled safely
        vm.applyStartupConversations(items)
        await repo.setFetchConversationsResult(.failure(NetworkError.serverError(statusCode: 500, traceId: "err")))
        await vm.loadMoreIfNeeded(current: items.last!)
        XCTAssertFalse(vm.isLoadingMore)
    }

    // MARK: - Search Tests

    func testSearchQueryChangedAndRefresh() async {
        let (vm, _, _, searchProvider) = makeViewModel()

        // Empty query resets search
        vm.onSearchQueryChanged("")
        XCTAssertTrue(vm.searchResults.isEmpty)
        guard case .idle = vm.searchState else { return XCTFail("Expected idle") }

        vm.onSearchQueryChanged("   ")
        XCTAssertTrue(vm.searchResults.isEmpty)

        // Search with query
        let userResult = MessagingSearchResult.user(UserSummary(id: UUID(), username: "john", displayName: "John"))
        searchProvider.searchResult = .success([userResult])

        await vm.refreshSearch(query: "john")
        XCTAssertEqual(vm.searchResults.count, 1)
        XCTAssertEqual(vm.activeSearchQuery, "john")
        guard case .loaded = vm.searchState else { return XCTFail("Expected loaded") }

        // Refresh search with empty string returns immediately
        await vm.refreshSearch(query: "")
        XCTAssertEqual(vm.activeSearchQuery, "john")

        // Search failure
        searchProvider.searchResult = .failure(NetworkError.serverError(statusCode: 500, traceId: "search-err"))
        await vm.refreshSearch(query: "fail")
        XCTAssertTrue(vm.searchResults.isEmpty)
        XCTAssertEqual(vm.activeSearchQuery, "")
        guard case .failed = vm.searchState else { return XCTFail("Expected failed search state") }
    }

    func testOnSearchQueryChangedDebouncedExecution() async {
        let (vm, _, _, searchProvider) = makeViewModel()
        let userResult = MessagingSearchResult.user(UserSummary(id: UUID(), username: "bob", displayName: "Bob"))
        searchProvider.searchResult = .success([userResult])

        vm.onSearchQueryChanged("bob")
        XCTAssertTrue(vm.isRefreshingSearch)

        // Wait for debounce (350ms)
        try? await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(vm.searchResults.count, 1)
        XCTAssertEqual(vm.activeSearchQuery, "bob")
        XCTAssertFalse(vm.isRefreshingSearch)

        // On error debounce
        searchProvider.searchResult = .failure(NetworkError.serverError(statusCode: 500, traceId: "err"))
        vm.onSearchQueryChanged("err")
        try? await Task.sleep(for: .milliseconds(450))
        XCTAssertTrue(vm.searchResults.isEmpty)
        guard case .failed = vm.searchState else { return XCTFail("Expected failed") }
    }

    // MARK: - Start Conversation & Route

    func testStartConversationAndRoute() async {
        let (vm, _, repo, _) = makeViewModel()
        let friend = UserSummary(id: UUID(), username: "alex", displayName: "Alex")
        let conv = makeTestConversation()
        await repo.setGetOrCreateResult(.success(conv))

        // Success
        let route = await vm.startConversation(with: friend)
        XCTAssertNotNil(route)
        XCTAssertEqual(route?.conversation.id, conv.id)
        XCTAssertNil(vm.startConversationError)

        // Failure
        await repo.setGetOrCreateResult(.failure(NetworkError.serverError(statusCode: 500, traceId: "err")))
        let failedRoute = await vm.startConversation(with: friend)
        XCTAssertNil(failedRoute)
        XCTAssertNotNil(vm.startConversationError)

        // Clear error
        vm.clearStartConversationError()
        XCTAssertNil(vm.startConversationError)

        // Route for message hit
        let hit = MessageSearchHit(
            messageId: UUID(),
            conversationId: UUID(),
            body: "Found message",
            createdAt: Date(),
            peer: ConversationPeer(userId: UUID(), username: "p", displayName: "P", avatarUrl: nil)
        )
        let hitRoute = vm.routeForMessageHit(hit)
        XCTAssertEqual(hitRoute.conversation.id, hit.conversationId)
        XCTAssertEqual(hitRoute.highlightMessageId, hit.messageId)
    }

    // MARK: - Peek Delete and Notification Tests

    func testDeleteAndMuteFromPeek() async {
        let (vm, _, repo, _) = makeViewModel()
        let c1 = makeTestConversation()
        vm.applyStartupConversations([c1])

        await vm.beginPeek(conversation: c1)
        XCTAssertEqual(vm.peekConversation?.id, c1.id)

        // Prepare delete
        vm.prepareDeleteFromPeek()
        XCTAssertNil(vm.peekConversation)

        // Cancel pending delete
        vm.cancelPendingDelete()

        // Begin peek again and delete
        await vm.beginPeek(conversation: c1)
        await vm.deletePeekedConversation()
        let deleted = await repo.deletedConversationIds
        XCTAssertEqual(deleted.first, c1.id)
        XCTAssertTrue(vm.conversations.isEmpty)
        XCTAssertNil(vm.peekConversation)
    }

    // MARK: - Visibility, Polling & Reconcile

    func testVisibilityAndPolling() async {
        let (vm, _, repo, _) = makeViewModel()
        let c1 = makeTestConversation()
        await repo.setFetchConversationsResult(.success(MessagingPage(items: [c1], hasMore: false)))

        // onInboxVisible triggers polling and softSync
        vm.onInboxVisible()
        // Second call doesn't crash or re-poll
        vm.startVisiblePolling()

        await vm.softSyncInbox()
        XCTAssertEqual(vm.conversations.count, 1)

        // onInboxHidden stops polling
        vm.onInboxHidden()

        // Reconcile visible inbox
        vm.toggleFilter(.groups)
        await vm.reconcileVisibleInbox()
        // Since c1 is direct, it gets pruned
        XCTAssertTrue(vm.conversations.isEmpty)
    }

    // MARK: - WebSocket Events and Helpers

    func testWebSocketConnectedTriggersRefresh() async {
        let (vm, wsClient, repo, _) = makeViewModel()
        let c1 = makeTestConversation()
        await repo.setFetchConversationsResult(.success(MessagingPage(items: [c1], hasMore: false)))

        wsClient.eventSubject.send(.connected)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(vm.conversations.count, 1)
    }

    func testWebSocketGroupMemberRemovedForSelf() async {
        let (vm, wsClient, _, _) = makeViewModel()
        let myId = UUID()
        vm.currentUserId = myId

        let groupConv = makeTestConversation(type: .group, groupName: "Party")
        vm.applyStartupConversations([groupConv])

        // Removed someone else: no change
        wsClient.eventSubject.send(.groupMemberRemoved(conversationId: groupConv.id, removedUserId: UUID(), selfLeave: false))
        await Task.yield()
        XCTAssertFalse(vm.conversations.first?.isRemovedFromGroup ?? true)

        // Removed self: sets leftAt
        wsClient.eventSubject.send(.groupMemberRemoved(conversationId: groupConv.id, removedUserId: myId, selfLeave: false))
        await Task.yield()
        XCTAssertTrue(vm.conversations.first?.isRemovedFromGroup ?? false)
    }

    func testHideConversationLocallyRemovesAndUpdatesUnread() {
        let (vm, _, _, _) = makeViewModel()
        let c1 = makeTestConversation(unreadCount: 2)
        let c2 = makeTestConversation(unreadCount: 0)
        vm.applyStartupConversations([c1, c2])
        vm.setUnreadConversationCountForTests(1)

        vm.hideConversationLocally(conversationId: c1.id)
        XCTAssertEqual(vm.conversations.count, 1)
        XCTAssertEqual(vm.unreadConversationCount, 0)
    }

    func testDirectoryChangeNotificationTriggersSoftSync() async {
        let (vm, _, repo, _) = makeViewModel()
        let c1 = makeTestConversation()
        await repo.setFetchConversationsResult(.success(MessagingPage(items: [c1], hasMore: false)))

        NotificationCenter.default.post(name: MessagingInboxMayHaveChanged.notification, object: nil)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(vm.conversations.count, 1)
    }
}
