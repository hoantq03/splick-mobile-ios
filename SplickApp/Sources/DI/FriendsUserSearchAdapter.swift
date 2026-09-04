import Foundation
import SplickDomain
import FeatureExpense
import FeatureSocialFeed

struct FriendsUserSearchAdapter: UserSearchUseCaseProtocol, Sendable {
    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol

    init(fetchFriendsUseCase: FetchFriendsUseCaseProtocol) {
        self.fetchFriendsUseCase = fetchFriendsUseCase
    }

    func execute(query: String, page: Int, limit: Int) async throws -> [UserSummary] {
        try await fetchFriendsUseCase.execute(query: query, page: page, limit: limit)
    }
}
