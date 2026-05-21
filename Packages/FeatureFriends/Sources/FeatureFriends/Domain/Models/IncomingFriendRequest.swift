import Foundation
import SplickDomain

public struct IncomingFriendRequest: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let requester: UserSummary
    public let message: String?
    public let createdAt: Date
    public let expiresAt: Date

    public init(
        id: UUID,
        requester: UserSummary,
        message: String?,
        createdAt: Date,
        expiresAt: Date
    ) {
        self.id = id
        self.requester = requester
        self.message = message
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}
