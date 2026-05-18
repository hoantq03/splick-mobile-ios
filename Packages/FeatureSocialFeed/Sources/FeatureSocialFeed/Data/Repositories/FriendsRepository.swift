import Foundation
import SplickDomain

public final class FriendsRepository: FriendsRepositoryProtocol, Sendable {
    public init() {}

    public func fetchFriends(query: String, page: Int, limit: Int) async throws -> [UserSummary] {
        _ = query
        _ = page
        _ = limit
        return []
    }
}
