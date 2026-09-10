import Foundation
import SplickDomain

public struct UserProfileStats: Equatable, Sendable {
    public let friendCount: Int
    public let postCount: Int
    public let groupCount: Int

    public init(friendCount: Int, postCount: Int, groupCount: Int) {
        self.friendCount = friendCount
        self.postCount = postCount
        self.groupCount = groupCount
    }
}

public struct PublicUserProfile: Equatable, Sendable {
    public let user: UserSummary
    public let friendStatus: FriendRelationStatus
    public let stats: UserProfileStats
    public let isOnline: Bool
    public let lastSeenAt: Date?

    public init(
        user: UserSummary,
        friendStatus: FriendRelationStatus,
        stats: UserProfileStats,
        isOnline: Bool = false,
        lastSeenAt: Date? = nil
    ) {
        self.user = user
        self.friendStatus = friendStatus
        self.stats = stats
        self.isOnline = isOnline
        self.lastSeenAt = lastSeenAt
    }
}
