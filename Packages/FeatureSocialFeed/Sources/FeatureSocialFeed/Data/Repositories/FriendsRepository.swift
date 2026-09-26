import Foundation
import FeatureFriends
import SplickDomain

public final class FriendsRepository: FriendsRepositoryProtocol, Sendable {
    private let searchRepository: FriendsManagementRepositoryProtocol

    public init(searchRepository: FriendsManagementRepositoryProtocol) {
        self.searchRepository = searchRepository
    }

    public func fetchFriends(query: String, page: Int, limit: Int) async throws -> [UserSummary] {
        try await searchRepository.searchUsers(query: query, page: page, size: limit)
            .map(\.user)
    }
}
