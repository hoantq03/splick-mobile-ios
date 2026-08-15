import Foundation

public struct NotificationDestination: Codable, Equatable, Sendable {
    public let screen: NotificationScreen
    /// Post id for `.postDetail`, conversation id for `.messages`, user id for `.userProfile`.
    public let postId: UUID?

    public init(screen: NotificationScreen, postId: UUID? = nil) {
        self.screen = screen
        self.postId = postId
    }

    public init(screen: String, postId: UUID? = nil) {
        self.init(screen: NotificationScreen(rawValue: screen) ?? .unknown, postId: postId)
    }

    public var postDetailId: UUID? {
        guard screen == .postDetail else { return nil }
        return postId
    }

    public var conversationId: UUID? {
        guard screen == .messages else { return nil }
        return postId
    }

    public var userProfileId: UUID? {
        guard screen == .userProfile else { return nil }
        return postId
    }
}

public enum NotificationScreen: String, Codable, Sendable {
    case inbox = "INBOX"
    case feed = "FEED"
    case postDetail = "POST_DETAIL"
    case friends = "FRIENDS"
    case expenses = "EXPENSES"
    case messages = "MESSAGES"
    case userProfile = "USER_PROFILE"
    case unknown = "UNKNOWN"
}
