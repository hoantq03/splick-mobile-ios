import Foundation
import SplickDomain

@MainActor
final class ExpenseUserSearchViewModel: ObservableObject {
    @Published private(set) var users: [UserSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = true

    private let useCase: UserSearchUseCaseProtocol?
    private let pageSize: Int
    private var page = 0
    private var query = ""
    private var loadTask: Task<Void, Never>?

    init(useCase: UserSearchUseCaseProtocol?, pageSize: Int = 10) {
        self.useCase = useCase
        self.pageSize = pageSize
    }

    func reset(query: String) {
        loadTask?.cancel()
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        page = 0
        users = []
        hasMore = true

        guard useCase != nil else { return }
        loadTask = Task { await loadMore() }
    }

    func loadMoreIfNeeded(current: UserSummary?) async {
        guard let current, current.id == users.last?.id else { return }
        await loadMore()
    }

    func loadMore() async {
        guard let useCase, hasMore, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let batch = try await useCase.execute(query: query, page: page, limit: pageSize)
            guard !Task.isCancelled else { return }
            users.append(contentsOf: batch)
            hasMore = batch.count == pageSize
            page += 1
        } catch {
            hasMore = false
        }
    }
}
