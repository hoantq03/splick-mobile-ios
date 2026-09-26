import Foundation
import SplickDomain

public struct FriendsPageResult: Sendable, Equatable {
    public let friends: [UserSummary]
    public let page: Int
    public let hasMore: Bool

    public init(friends: [UserSummary], page: Int, hasMore: Bool) {
        self.friends = friends
        self.page = page
        self.hasMore = hasMore
    }
}
