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

    private let fetchConversationsUseCase: FetchConversationsUseCase
    private let wsClient: MessagingWebSocketClient
    private var cancellables = Set<AnyCancellable>()

    public init(
        fetchConversationsUseCase: FetchConversationsUseCase,
        wsClient: MessagingWebSocketClient
    ) {
        self.fetchConversationsUseCase = fetchConversationsUseCase
        self.wsClient = wsClient
        bindWsEvents()
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
