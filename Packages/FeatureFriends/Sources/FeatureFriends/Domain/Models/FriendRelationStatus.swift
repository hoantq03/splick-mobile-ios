import Foundation
import SplickDomain

public enum FriendProfileMode: Sendable {
    case friend
    case stranger
    case blocked
}

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
    public let distanceMeters: Int?

    public var id: UUID { user.id }

    public init(user: UserSummary, friendStatus: FriendRelationStatus, distanceMeters: Int? = nil) {
        self.user = user
        self.friendStatus = friendStatus
        self.distanceMeters = distanceMeters
    }
}

public extension FriendRelationStatus {
    var profileMode: FriendProfileMode {
        switch self {
        case .friends:
            return .friend
        case .blocked:
            return .blocked
        case .none, .requestSent, .requestReceived:
            return .stranger
        }
    }
}
