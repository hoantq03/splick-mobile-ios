import Foundation

public enum SearchHistoryScope: String, Codable, Sendable, CaseIterable {
    case friends = "FRIENDS"
    case messaging = "MESSAGING"
    case messagingThread = "MESSAGING_THREAD"
    case album = "ALBUM"
    case location = "LOCATION"
    case expense = "EXPENSE"
    case gif = "GIF"
}

public struct SearchHistoryItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let scope: SearchHistoryScope
    public let scopeKey: String?
    public let query: String
    public let lastUsedAt: Date

    public init(
        id: UUID,
        scope: SearchHistoryScope,
        scopeKey: String?,
        query: String,
        lastUsedAt: Date
    ) {
        self.id = id
        self.scope = scope
        self.scopeKey = scopeKey
        self.query = query
        self.lastUsedAt = lastUsedAt
    }
}

public protocol SearchHistoryLocalStore: Sendable {
    func load(for key: String) -> [SearchHistoryItem]
    func save(_ items: [SearchHistoryItem], for key: String)
    func remove(for key: String)
}
