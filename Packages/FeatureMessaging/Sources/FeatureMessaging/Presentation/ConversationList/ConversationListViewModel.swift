import SwiftUI
import Combine
import Common
import Localization
import SplickDomain

@MainActor
public final class ConversationListViewModel: ObservableObject {

    public enum InboxFilter: Equatable {
        case groups
        case users
        case unread
        case closeFriends
    }

    public enum State {
        case idle
        case loading
        case loaded([Conversation])
        case failed(String)
    }

    public enum PeekLoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var searchResults: [MessagingSearchResult] = []
    @Published public private(set) var searchState: LoadingState<[MessagingSearchResult]> = .idle
    @Published public private(set) var isRefreshingSearch = false
    /// Query used for result highlighting — updates when a search completes, not on every keystroke.
    @Published public private(set) var activeSearchQuery = ""
    @Published public private(set) var isStartingConversation = false
    @Published public var startConversationError: String?
    @Published public private(set) var activeFilter: InboxFilter?
    @Published public private(set) var hasMorePages = false
    @Published public private(set) var isLoadingMore = false
    @Published public private(set) var unreadConversationCount = 0
    @Published public private(set) var peekConversation: Conversation?
    @Published public private(set) var peekMessages: [ChatMessage] = []
    @Published public private(set) var peekLoadState: PeekLoadState = .idle
    @Published public private(set) var typingUserIdsByConversation: [UUID: [UUID]] = [:]

    /// Used to decide whether an incoming WS message should bump unread.
    public var currentUserId: UUID?

    private static let pageSize = 20
    private static let peekMessageLimit = 8
    private static let wsRefreshDebounce: Duration = .seconds(30)

    private let fetchConversationsUseCase: FetchConversationsUseCase
    private let fetchMessagesUseCase: FetchMessagesUseCase
    private let searchProvider: MessagingSearchProviding
    private let repository: MessagingRepositoryProtocol
    private let wsClient: MessagingWebSocketClient
    private let languageService: LanguageService
    private let messageCache: MessageThreadCache?
    private let onInboxLoaded: (([Conversation], Int) async -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var peekTask: Task<MessagingPage<ChatMessage>, Error>?
    private var debouncedRefreshTask: Task<Void, Never>?
    private var remoteTypingTimeouts: [String: Task<Void, Never>] = [:]
    private var currentPage = 0
    private var pendingDeleteConversationId: UUID?
    private var refreshQueued = false

    public init(
        fetchConversationsUseCase: FetchConversationsUseCase,
        fetchMessagesUseCase: FetchMessagesUseCase,
        searchProvider: MessagingSearchProviding,
        repository: MessagingRepositoryProtocol,
        wsClient: MessagingWebSocketClient,
        languageService: LanguageService,
        messageCache: MessageThreadCache? = nil,
        onInboxLoaded: (([Conversation], Int) async -> Void)? = nil
    ) {
        self.fetchConversationsUseCase = fetchConversationsUseCase
        self.fetchMessagesUseCase = fetchMessagesUseCase
        self.searchProvider = searchProvider
        self.repository = repository
        self.wsClient = wsClient
        self.languageService = languageService
        self.messageCache = messageCache
        self.onInboxLoaded = onInboxLoaded
        bindWsEvents()
    }

    /// Applies a WS inbox patch without going through the live event subject (tests).
    public func handleIncomingWsMessageForTesting(conversationId: UUID, message: ChatMessage) {
        applyIncomingMessage(conversationId: conversationId, message: message)
    }

    public func handleIncomingTypingForTesting(
        conversationId: UUID,
        userId: UUID,
        isTyping: Bool
    ) {
        applyRemoteTyping(conversationId: conversationId, userId: userId, isTyping: isTyping)
    }

    public var conversations: [Conversation] {
        if case .loaded(let items) = state { return items }
        return []
    }

    public func beginPeek(conversation: Conversation) async {
        peekTask?.cancel()
        peekConversation = conversation
        peekMessages = []
        peekLoadState = .loading

        let conversationId = conversation.id
        let task = Task {
            try await fetchMessagesUseCase.execute(
                conversationId: conversationId,
                page: 0,
                limit: Self.peekMessageLimit
            )
        }
        peekTask = task

        do {
            let page = try await task.value
            guard !Task.isCancelled, peekConversation?.id == conversationId else { return }
            // Don't cancel the peek row bounce when preview content arrives.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                peekMessages = Array(page.items.reversed())
                peekLoadState = .loaded
            }
        } catch is CancellationError {
            return
        } catch {
            guard peekConversation?.id == conversationId else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                peekLoadState = .failed
            }
            Log.error(
                error,
                category: .network,
                metadata: ["action": "previewConversation", "conversationId": conversationId.uuidString]
            )
        }
    }

    public func dismissPeek() {
        peekTask?.cancel()
        peekTask = nil
        peekConversation = nil
        peekMessages = []
        peekLoadState = .idle
    }

    public func deletePeekedConversation() async {
        let conversationId = peekConversation?.id ?? pendingDeleteConversationId
        guard let conversationId else { return }
        pendingDeleteConversationId = nil
        do {
            try await repository.deleteConversation(conversationId: conversationId)
            hideConversationLocally(conversationId: conversationId)
            dismissPeek()
        } catch {
            Log.error(
                error,
                category: .network,
                metadata: ["action": "deletePeekedConversation", "conversationId": conversationId.uuidString]
            )
        }
    }

    public func prepareDeleteFromPeek() {
        pendingDeleteConversationId = peekConversation?.id
        dismissPeek()
    }

    public func cancelPendingDelete() {
        pendingDeleteConversationId = nil
    }

    public func hideConversationLocally(conversationId: UUID) {
        messageCache?.remove(conversationId: conversationId)
        removeConversationFromInbox(conversationId)
    }

    public func toggleFilter(_ filter: InboxFilter) {
        guard filter != .closeFriends else { return }
        activeFilter = activeFilter == filter ? nil : filter
        Task { await reloadInbox(showLoadingState: conversations.isEmpty) }
    }

    public func isFilterActive(_ filter: InboxFilter) -> Bool {
        activeFilter == filter
    }

    /// Conversation the user is currently viewing — incoming WS must not keep it unread.
    public private(set) var activeConversationId: UUID?

    public func setActiveConversation(_ conversationId: UUID) {
        activeConversationId = conversationId
        markConversationAsRead(conversationId: conversationId)
    }

    public func clearActiveConversation(_ conversationId: UUID) {
        if activeConversationId == conversationId {
            activeConversationId = nil
        }
        markConversationAsRead(conversationId: conversationId)
    }

    /// Re-applies the selected inbox filter and unread badge after leaving a thread.
    public func reconcileVisibleInbox() async {
        pruneConversationsToActiveFilter()
        await refreshInboxSummary()
        pruneConversationsToActiveFilter()
    }

    func setActiveFilterForTests(_ filter: InboxFilter?) {
        activeFilter = filter
    }

    func setUnreadConversationCountForTests(_ count: Int) {
        unreadConversationCount = count
    }

    public func applyStartupConversations(_ items: [Conversation]) {
        guard !items.isEmpty else { return }
        state = .loaded(items)
        hasMorePages = items.count >= Self.pageSize
        currentPage = 0
    }

    public func load() async {
        if case .loaded = state { return }
        await reloadInbox(showLoadingState: conversations.isEmpty)
    }

    public func refresh() async {
        if let existing = refreshTask {
            refreshQueued = true
            await existing.value
            guard refreshQueued else { return }
            refreshQueued = false
            await refresh()
            return
        }

        let task = Task { @MainActor in
            await reloadInbox(showLoadingState: false)
        }
        refreshTask = task
        await task.value
        refreshTask = nil
        if refreshQueued {
            refreshQueued = false
            await refresh()
        }
    }

    public func loadMoreIfNeeded(current conversation: Conversation) async {
        guard hasMorePages, !isLoadingMore, !isLoadingList else { return }
        guard conversations.last?.id == conversation.id else { return }

        if let existing = loadMoreTask {
            await existing.value
            return
        }

        let task = Task { @MainActor in
            await performLoadMore()
        }
        loadMoreTask = task
        await task.value
        loadMoreTask = nil
    }

    public func refreshSearch(query: String) async {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let task = Task { @MainActor in
            do {
                let results = try await searchProvider.search(query: trimmed)
                guard !Task.isCancelled else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    searchResults = results
                    searchState = .loaded(results)
                    activeSearchQuery = trimmed
                    isRefreshingSearch = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    searchResults = []
                    searchState = .failed(languageService.localizedMessage(for: error))
                    activeSearchQuery = ""
                    isRefreshingSearch = false
                }
                Log.error(error, category: .network, metadata: ["action": "searchMessaging", "query": trimmed])
            }
        }
        searchTask = task
        await task.value
    }

    public func onSearchQueryChanged(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            searchState = .idle
            isRefreshingSearch = false
            activeSearchQuery = ""
            return
        }

        if searchResults.isEmpty, case .idle = searchState {
            searchState = .loading
        }
        if !isRefreshingSearch {
            isRefreshingSearch = true
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            do {
                let results = try await searchProvider.search(query: trimmed)
                guard !Task.isCancelled else { return }
                searchResults = results
                searchState = .loaded(results)
                activeSearchQuery = trimmed
                isRefreshingSearch = false
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
                searchState = .failed(languageService.localizedMessage(for: error))
                activeSearchQuery = ""
                isRefreshingSearch = false
                Log.error(error, category: .network, metadata: ["action": "searchMessaging", "query": trimmed])
            }
        }
    }

    public func clearStartConversationError() {
        startConversationError = nil
    }

    public func markConversationAsRead(conversationId: UUID) {
        guard case .loaded(let items) = state,
              let existing = items.first(where: { $0.id == conversationId }) else {
            return
        }
        applyConversationToInbox(existing.updating(unreadCount: 0), moveToTop: false)
    }

    public func upsertConversation(_ updated: Conversation) {
        applyConversationToInbox(updated, moveToTop: false)
    }

    private func removeConversationFromInbox(_ conversationId: UUID) {
        guard case .loaded(var items) = state,
              let index = items.firstIndex(where: { $0.id == conversationId }) else { return }

        let unread = items[index].unreadCount
        items.remove(at: index)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            state = .loaded(items)
            if unread > 0 {
                unreadConversationCount = max(0, unreadConversationCount - 1)
            }
        }
    }

    public func startConversation(with user: UserSummary) async -> ChatThreadRoute? {
        guard !isStartingConversation else { return nil }
        isStartingConversation = true
        startConversationError = nil
        defer { isStartingConversation = false }

        do {
            let conversation = try await repository.getOrCreateConversation(friendUserId: user.id)
            return ChatThreadRoute(conversation: conversation)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "getOrCreateConversation"])
            startConversationError = languageService.localizedMessage(for: error)
            return nil
        }
    }

    public func routeForMessageHit(_ hit: MessageSearchHit) -> ChatThreadRoute {
        let conversation = Conversation(
            id: hit.conversationId,
            unreadCount: 0,
            peer: hit.peer,
            lastMessage: nil,
            createdAt: hit.createdAt,
            updatedAt: hit.createdAt
        )
        return ChatThreadRoute(conversation: conversation, highlightMessageId: hit.messageId)
    }

    private var isLoadingList: Bool {
        if case .loading = state { return true }
        return false
    }

    private func reloadInbox(showLoadingState: Bool = true) async {
        currentPage = 0
        hasMorePages = false
        if showLoadingState {
            state = .loading
        }

        do {
            async let conversationsTask = fetchConversationsUseCase.execute(query: inboxQuery(page: 0))
            async let summaryTask = repository.fetchConversationInboxSummary()
            let (page, summary) = try await (conversationsTask, summaryTask)

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                state = .loaded(page.items)
                unreadConversationCount = summary
                hasMorePages = page.hasMore
            }
            await onInboxLoaded?(page.items, summary)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "reloadInbox"])
            if showLoadingState || conversations.isEmpty {
                state = .failed(languageService.localizedMessage(for: error))
            }
        }
    }

    private func performLoadMore() async {
        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1
        do {
            let page = try await fetchConversationsUseCase.execute(query: inboxQuery(page: nextPage))
            guard !page.items.isEmpty else {
                hasMorePages = false
                return
            }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                let merged = conversations + page.items
                state = .loaded(merged)
                currentPage = nextPage
                hasMorePages = page.hasMore
            }
        } catch {
            Log.error(error, category: .network, metadata: ["action": "loadMoreConversations"])
        }
    }

    private func inboxQuery(page: Int) -> ConversationInboxQuery {
        switch activeFilter {
        case .groups:
            return ConversationInboxQuery(
                page: page,
                limit: Self.pageSize,
                type: .group,
                unreadOnly: false
            )
        case .users:
            return ConversationInboxQuery(
                page: page,
                limit: Self.pageSize,
                type: .direct,
                unreadOnly: false
            )
        case .unread:
            return ConversationInboxQuery(
                page: page,
                limit: Self.pageSize,
                type: nil,
                unreadOnly: true
            )
        case .closeFriends, .none:
            return ConversationInboxQuery(page: page, limit: Self.pageSize)
        }
    }

    private func matchesActiveFilter(_ conversation: Conversation) -> Bool {
        switch activeFilter {
        case .groups:
            return conversation.isGroup
        case .users:
            return !conversation.isGroup
        case .unread:
            return conversation.unreadCount > 0
        case .closeFriends, .none:
            return true
        }
    }

    private func pruneConversationsToActiveFilter() {
        guard case .loaded(let items) = state else { return }
        let pruned = items.filter(matchesActiveFilter)
        guard pruned.count != items.count else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            state = .loaded(pruned)
        }
    }

    private func refreshInboxSummary() async {
        do {
            let summary = try await repository.fetchConversationInboxSummary()
            unreadConversationCount = summary
        } catch {
            Log.error(error, category: .network, metadata: ["action": "refreshInboxSummary"])
        }
    }

    private func applyConversationToInbox(_ updated: Conversation, moveToTop: Bool) {
        let items: [Conversation]
        if case .loaded(let current) = state {
            items = current
        } else {
            items = []
        }
        let existing = items.first(where: { $0.id == updated.id })
        let wasUnread = (existing?.unreadCount ?? 0) > 0
        let isUnread = updated.unreadCount > 0
        let unreadDelta: Int
        if existing == nil {
            unreadDelta = 0
        } else if !wasUnread && isUnread {
            unreadDelta = 1
        } else if wasUnread && !isUnread {
            unreadDelta = -1
        } else {
            unreadDelta = 0
        }
        let matches = matchesActiveFilter(updated)
        let next: [Conversation]
        if matches, existing != nil {
            if moveToTop {
                next = [updated] + items.filter { $0.id != updated.id }
            } else {
                next = items.map { $0.id == updated.id ? updated : $0 }
            }
        } else if matches, existing == nil {
            next = [updated] + items
        } else if !matches, existing != nil {
            next = items.filter { $0.id != updated.id }
        } else {
            next = items
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            state = .loaded(next)
            if unreadDelta != 0 {
                unreadConversationCount = max(0, unreadConversationCount + unreadDelta)
            }
        }
    }

    private func bindWsEvents() {
        wsClient.eventsPublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .connected:
                    // Missed WS events while backgrounded are not replayed — REST catch-up.
                    Task { await self.refresh() }
                case .newMessage(let conversationId, let message):
                    self.applyIncomingMessage(conversationId: conversationId, message: message)
                case .groupMemberRemoved(let conversationId, let removedUserId, _):
                    if self.currentUserId == removedUserId {
                        self.applyRemovedFromGroup(conversationId: conversationId)
                    }
                case .typing(let conversationId, let userId, let isTyping):
                    self.applyRemoteTyping(
                        conversationId: conversationId,
                        userId: userId,
                        isTyping: isTyping
                    )
                case .presence(let userId, let isOnline, let lastSeenAt):
                    self.applyPeerPresence(
                        userId: userId,
                        isOnline: isOnline,
                        lastSeenAt: lastSeenAt
                    )
                case .messageEdited(let conversationId, let messageId, _, let body, let editedAt):
                    self.applyEditedMessage(
                        conversationId: conversationId,
                        messageId: messageId,
                        body: body,
                        editedAt: editedAt
                    )
                case .messageRecalled(let conversationId, let messageId, _):
                    self.applyRecalledMessage(
                        conversationId: conversationId,
                        messageId: messageId
                    )
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func applyRemovedFromGroup(conversationId: UUID) {
        guard case .loaded(var items) = state,
              let index = items.firstIndex(where: { $0.id == conversationId }) else {
            return
        }
        let existing = items[index]
        if existing.leftAt != nil { return }
        items[index] = existing.updating(leftAt: Date())
        state = .loaded(items)
    }

    /// Patches the inbox row from the WS payload instead of refetching the whole list.
    private func applyIncomingMessage(conversationId: UUID, message: ChatMessage) {
        let isFromSelf = currentUserId.map { message.senderId == $0 } ?? false
        if !isFromSelf {
            MessageDeliveryAckService.shared.acknowledge(
                conversationId: conversationId,
                messageId: message.id
            )
        }

        guard case .loaded(let items) = state,
              let index = items.firstIndex(where: { $0.id == conversationId }) else {
            Task { await self.refresh() }
            return
        }

        let existing = items[index]
        if existing.leftAt != nil { return }
        let viewingOpenThread = activeConversationId == conversationId
        let nextUnread: Int
        if isFromSelf || viewingOpenThread {
            nextUnread = 0
        } else {
            nextUnread = existing.unreadCount + 1
        }

        let patched = existing.updating(
            lastMessage: message,
            unreadCount: nextUnread,
            updatedAt: message.createdAt
        )
        applyConversationToInbox(patched, moveToTop: true)
        if !viewingOpenThread {
            scheduleDebouncedRefresh()
        }
    }

    private func applyEditedMessage(
        conversationId: UUID,
        messageId: UUID,
        body: String,
        editedAt: Date?
    ) {
        patchLastMessage(conversationId: conversationId, messageId: messageId) { message in
            message.updating(body: body, editedAt: editedAt ?? Date())
        }
    }

    private func applyRecalledMessage(conversationId: UUID, messageId: UUID) {
        patchLastMessage(conversationId: conversationId, messageId: messageId) { message in
            message.updatingAsRecalled()
        }
    }

    private func patchLastMessage(
        conversationId: UUID,
        messageId: UUID,
        transform: (ChatMessage) -> ChatMessage
    ) {
        guard case .loaded(var items) = state,
              let index = items.firstIndex(where: { $0.id == conversationId }) else {
            return
        }
        let existing = items[index]
        guard let lastMessage = existing.lastMessage, lastMessage.id == messageId else {
            return
        }
        let patched = existing.updating(
            lastMessage: transform(lastMessage),
            unreadCount: existing.unreadCount,
            updatedAt: Date()
        )
        items[index] = patched
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            state = .loaded(items)
        }
    }

    private func applyRemoteTyping(conversationId: UUID, userId: UUID, isTyping: Bool) {
        if let currentUserId, userId == currentUserId { return }
        let timeoutKey = "\(conversationId.uuidString)-\(userId.uuidString)"
        remoteTypingTimeouts[timeoutKey]?.cancel()
        var current = typingUserIdsByConversation[conversationId] ?? []
        if isTyping {
            if !current.contains(userId) {
                current.append(userId)
            }
            typingUserIdsByConversation[conversationId] = current
            remoteTypingTimeouts[timeoutKey] = Task { [weak self] in
                try? await Task.sleep(for: .seconds(MessagingTypingTiming.displayTimeout))
                guard !Task.isCancelled else { return }
                self?.removeRemoteTyping(conversationId: conversationId, userId: userId)
            }
        } else {
            removeRemoteTyping(conversationId: conversationId, userId: userId)
        }
    }

    private func removeRemoteTyping(conversationId: UUID, userId: UUID) {
        let timeoutKey = "\(conversationId.uuidString)-\(userId.uuidString)"
        remoteTypingTimeouts[timeoutKey]?.cancel()
        remoteTypingTimeouts[timeoutKey] = nil
        var current = typingUserIdsByConversation[conversationId] ?? []
        current.removeAll { $0 == userId }
        if current.isEmpty {
            typingUserIdsByConversation.removeValue(forKey: conversationId)
        } else {
            typingUserIdsByConversation[conversationId] = current
        }
    }

    private func applyPeerPresence(userId: UUID, isOnline: Bool, lastSeenAt: Date?) {
        guard case .loaded(var items) = state else { return }
        var changed = false
        items = items.map { conversation in
            guard let peer = conversation.peer, peer.userId == userId else { return conversation }
            changed = true
            return conversation.updating(
                peer: peer.updatingPresence(isOnline: isOnline, lastSeenAt: lastSeenAt)
            )
        }
        if changed {
            state = .loaded(items)
        }
    }

    private func scheduleDebouncedRefresh() {
        debouncedRefreshTask?.cancel()
        debouncedRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: Self.wsRefreshDebounce)
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }
}
