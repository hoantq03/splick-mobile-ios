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

    /// Direct chats can compose only after friendship is confirmed.
    public var canComposeDirectMessages: Bool {
        self == .friends
    }

    public var isBlocked: Bool {
        self == .blocked
    }

    public var canRemoveFriend: Bool {
        self == .friends
    }
}
