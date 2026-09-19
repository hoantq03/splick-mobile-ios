import Foundation
import SplickDomain

public protocol FriendsRepositoryProtocol: Sendable {
    func fetchFriends(query: String, page: Int, limit: Int) async throws -> [UserSummary]
}
