import Foundation
import SplickDomain

public struct BlockedUser: Identifiable, Sendable, Equatable {
    public var id: UUID { user.id }
    public let user: UserSummary
    public let blockedAt: Date

    public init(user: UserSummary, blockedAt: Date) {
        self.user = user
        self.blockedAt = blockedAt
    }
}
