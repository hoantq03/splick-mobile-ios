import Foundation
import SplickDomain

public enum FriendRelationStatus: String, Sendable, Equatable {
    case none = "NONE"
    case friends = "FRIENDS"
    case requestSent = "REQUEST_SENT"
    case requestReceived = "REQUEST_RECEIVED"
    case blocked = "BLOCKED"
}

public struct UserSearchResult: Identifiable, Sendable, Equatable {
    public let user: UserSummary
    public let friendStatus: FriendRelationStatus

    public var id: UUID { user.id }

    public init(user: UserSummary, friendStatus: FriendRelationStatus) {
        self.user = user
        self.friendStatus = friendStatus
    }
}
