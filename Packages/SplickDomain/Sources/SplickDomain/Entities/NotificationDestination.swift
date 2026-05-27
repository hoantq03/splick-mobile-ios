import Foundation

public struct NotificationDestination: Codable, Equatable, Sendable {
    public let screen: String
    public let postId: UUID?

    public init(screen: String, postId: UUID? = nil) {
        self.screen = screen
        self.postId = postId
    }

    public var postDetailId: UUID? {
        screen == "POST_DETAIL" ? postId : nil
    }
}
