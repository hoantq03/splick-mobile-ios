import Foundation

public struct UserPresenceState: Equatable, Sendable {
    public let userId: UUID
    public let isOnline: Bool
    public let lastSeenAt: Date?

    public init(userId: UUID, isOnline: Bool, lastSeenAt: Date?) {
        self.userId = userId
        self.isOnline = isOnline
        self.lastSeenAt = lastSeenAt
    }
}
