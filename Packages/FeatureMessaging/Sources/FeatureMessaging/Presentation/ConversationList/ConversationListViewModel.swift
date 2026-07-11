import SwiftUI
import Combine
import Common
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

    private static let pageSize = 20

    private let fetchConversationsUseCase: FetchConversationsUseCase
    private let searchProvider: MessagingSearchProviding
    private let repository: MessagingRepositoryProtocol
    private let wsClient: MessagingWebSocketClient
    private let onInboxLoaded: (([Conversation], Int) async -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var currentPage = 0

    public init(
        fetchConversationsUseCase: FetchConversationsUseCase,
        searchProvider: MessagingSearchProviding,
        repository: MessagingRepositoryProtocol,
        wsClient: MessagingWebSocketClient,
        onInboxLoaded: (([Conversation], Int) async -> Void)? = nil
    ) {
        self.fetchConversationsUseCase = fetchConversationsUseCase
        self.searchProvider = searchProvider
        self.repository = repository
        self.wsClient = wsClient
        self.onInboxLoaded = onInboxLoaded
        bindWsEvents()
    }

    public var conversations: [Conversation] {
        if case .loaded(let items) = state { return items }
        return []
    }

    public func toggleFilter(_ filter: InboxFilter) {
        guard filter != .closeFriends else { return }
        activeFilter = activeFilter == filter ? nil : filter
        Task { await reloadInbox(showLoadingState: conversations.isEmpty) }
    }

    public func isFilterActive(_ filter: InboxFilter) -> Bool {
        activeFilter == filter
    }

    public func applyStartupConversations(_ items: [Conversation]) {
        guard !items.isEmpty else { return }
        state = .loaded(items)
        hasMorePages = items.count >= Self.pageSize
        currentPage = 0
    }

    public func load() async {
        if case .loaded = state { return }
        state = .loading
        await reloadInbox(showLoadingState: false)
    }

    public func refresh() async {
        if let existing = refreshTask {
            await existing.value
            return
        }

        let task = Task { @MainActor in
            await reloadInbox(showLoadingState: false)
        }
        refreshTask = task
        await task.value
        refreshTask = nil
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
                    searchState = .failed(error.localizedDescription)
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
                searchState = .failed(error.localizedDescription)
                activeSearchQuery = ""
                isRefreshingSearch = false
                Log.error(error, category: .network, metadata: ["action": "searchMessaging", "query": trimmed])
            }
        }
    }

    public func clearStartConversationError() {
        startConversationError = nil
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
            startConversationError = error.localizedDescription
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
            let (items, summary) = try await (conversationsTask, summaryTask)

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                state = .loaded(items)
                unreadConversationCount = summary
                hasMorePages = items.count >= Self.pageSize
            }
            await onInboxLoaded?(items, summary)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "reloadInbox"])
            if showLoadingState || conversations.isEmpty {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func performLoadMore() async {
        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1
        do {
            let items = try await fetchConversationsUseCase.execute(query: inboxQuery(page: nextPage))
            guard !items.isEmpty else {
                hasMorePages = false
                return
            }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                let merged = conversations + items
                state = .loaded(merged)
                currentPage = nextPage
                hasMorePages = items.count >= Self.pageSize
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

    private func bindWsEvents() {
        wsClient.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                if case .newMessage = event {
                    Task { await self.refresh() }
                }
            }
            .store(in: &cancellables)
    }
}
