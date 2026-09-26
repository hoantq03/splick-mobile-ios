import Foundation
import SplickDomain

public protocol InboxFriendsProviding: Sendable {
    func fetchFriends() async throws -> [UserSummary]
}
