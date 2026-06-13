import Foundation
import Combine
import Common
import SplickDomain

@MainActor
public final class NewConversationViewModel: ObservableObject {

    public enum State {
        case idle
        case loading
        case loaded([UserSummary])
        case failed(String)
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var isCreating = false
    @Published public var createError: String?

    private let friendsProvider: FriendsListProviding
    private let repository: MessagingRepositoryProtocol
    private let onConversationCreated: (Conversation) -> Void

    public init(
        friendsProvider: FriendsListProviding,
        repository: MessagingRepositoryProtocol,
        onConversationCreated: @escaping (Conversation) -> Void
    ) {
        self.friendsProvider = friendsProvider
        self.repository = repository
        self.onConversationCreated = onConversationCreated
    }

    public var friends: [UserSummary] {
        if case .loaded(let list) = state { return list }
        return []
    }

    public func load() async {
        state = .loading
        do {
            let list = try await friendsProvider.fetchFriends()
            state = .loaded(list)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "loadFriendsForNewConversation"])
            state = .failed(error.localizedDescription)
        }
    }

    public func clearCreateError() {
        createError = nil
    }

    @discardableResult
    public func startConversation(with friend: UserSummary) async -> Bool {
        guard !isCreating else { return false }
        isCreating = true
        createError = nil
        defer { isCreating = false }

        do {
            let conversation = try await repository.getOrCreateConversation(friendUserId: friend.id)
            onConversationCreated(conversation)
            return true
        } catch {
            Log.error(error, category: .network, metadata: ["action": "getOrCreateConversation"])
            createError = error.localizedDescription
            return false
        }
    }
}
