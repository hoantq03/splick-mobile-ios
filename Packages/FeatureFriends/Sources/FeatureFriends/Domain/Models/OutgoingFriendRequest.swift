import Foundation
import SplickDomain

public struct OutgoingFriendRequest: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let addressee: UserSummary
    public let message: String?
    public let createdAt: Date
    public let expiresAt: Date

    public init(
        id: UUID,
        addressee: UserSummary,
        message: String?,
        createdAt: Date,
        expiresAt: Date
    ) {
        self.id = id
        self.addressee = addressee
        self.message = message
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}
