import Foundation
import Combine
import Common
import SplickDomain

@MainActor
public final class ConversationListViewModel: ObservableObject {

    public enum State {
        case idle
        case loading
        case loaded([Conversation])
        case failed(String)
    }

    @Published public private(set) var state: State = .idle
    @Published public var searchQuery = ""
    @Published public private(set) var searchResults: [MessagingSearchResult] = []
    @Published public private(set) var searchState: LoadingState<[MessagingSearchResult]> = .idle
    @Published public private(set) var isRefreshingSearch = false
    @Published public private(set) var isStartingConversation = false
    @Published public var startConversationError: String?

    private let fetchConversationsUseCase: FetchConversationsUseCase
    private let searchProvider: MessagingSearchProviding
    private let repository: MessagingRepositoryProtocol
    private let wsClient: MessagingWebSocketClient
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    public init(
        fetchConversationsUseCase: FetchConversationsUseCase,
        searchProvider: MessagingSearchProviding,
        repository: MessagingRepositoryProtocol,
        wsClient: MessagingWebSocketClient
    ) {
        self.fetchConversationsUseCase = fetchConversationsUseCase
        self.searchProvider = searchProvider
        self.repository = repository
        self.wsClient = wsClient
        bindWsEvents()
    }

    public var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var conversations: [Conversation] {
        if case .loaded(let items) = state { return items }
        return []
    }

    public func load() async {
        state = .loading
        do {
            let items = try await fetchConversationsUseCase.execute()
            state = .loaded(items)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "loadConversations"])
            state = .failed(error.localizedDescription)
        }
    }

    public func refresh() async {
        do {
            let items = try await fetchConversationsUseCase.execute()
            state = .loaded(items)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "refreshConversations"])
        }
    }

    public func onSearchQueryChanged(_ query: String) {
        searchQuery = query
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            searchState = .idle
            isRefreshingSearch = false
            return
        }

        if case .idle = searchState {
            searchState = .loading
        }
        isRefreshingSearch = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            do {
                let results = try await searchProvider.search(query: trimmed)
                guard !Task.isCancelled else { return }
                searchResults = results
                searchState = .loaded(results)
                isRefreshingSearch = false
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
                searchState = .failed(error.localizedDescription)
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
