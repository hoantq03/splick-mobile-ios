import Foundation

/// Cursor / limit page envelope shared by messaging list endpoints.
public struct MessagingPage<Element: Sendable>: Sendable {
    public let items: [Element]
    public let nextCursor: String?
    public let hasMore: Bool

    public init(items: [Element], nextCursor: String? = nil, hasMore: Bool) {
        self.items = items
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}
