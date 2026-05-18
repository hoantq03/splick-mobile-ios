import Foundation
import Combine
import SplickDomain

@MainActor
final class MentionFriendsViewModel: ObservableObject {
    @Published private(set) var friends: [UserSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = true

    private let useCase: FetchFriendsUseCaseProtocol
    private let pageSize: Int
    private var page = 0
    private var query = ""
    private var loadTask: Task<Void, Never>?

    init(useCase: FetchFriendsUseCaseProtocol, pageSize: Int = 10) {
        self.useCase = useCase
        self.pageSize = pageSize
    }

    func reset(query: String) {
        loadTask?.cancel()
        self.query = query
        page = 0
        friends = []
        hasMore = true
        loadTask = Task { await loadMore() }
    }

    func loadMoreIfNeeded(currentFriend: UserSummary?) async {
        guard let currentFriend, currentFriend.id == friends.last?.id else { return }
        await loadMore()
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let batch = try await useCase.execute(query: query, page: page, limit: pageSize)
            guard !Task.isCancelled else { return }
            friends.append(contentsOf: batch)
            hasMore = batch.count == pageSize
            page += 1
        } catch {
            hasMore = false
        }
    }
}
