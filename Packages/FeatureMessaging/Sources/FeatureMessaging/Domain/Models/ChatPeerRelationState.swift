import Foundation

public enum ChatPeerRelationState: Equatable, Sendable {
    case unknown
    case friends
    case blocked
    case stranger
    case requestSent
    case requestReceived

    public var showsAddFriendBanner: Bool {
        switch self {
        case .stranger, .requestSent, .requestReceived:
            return true
        case .unknown, .friends, .blocked:
            return false
        }
    }

    public var isBlocked: Bool {
        self == .blocked
    }

    public var canRemoveFriend: Bool {
        self == .friends
    }
}
