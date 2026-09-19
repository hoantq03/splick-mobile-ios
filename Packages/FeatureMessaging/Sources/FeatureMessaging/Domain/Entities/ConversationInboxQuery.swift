import Foundation

public struct ConversationInboxQuery: Equatable, Sendable {
    public let page: Int
    public let limit: Int
    public let type: ConversationType?
    public let unreadOnly: Bool

    public init(
        page: Int = 0,
        limit: Int = 20,
        type: ConversationType? = nil,
        unreadOnly: Bool = false
    ) {
        self.page = page
        self.limit = limit
        self.type = type
        self.unreadOnly = unreadOnly
    }
}
