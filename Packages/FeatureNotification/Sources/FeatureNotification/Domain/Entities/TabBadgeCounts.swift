import Foundation

public struct TabBadgeCounts: Equatable, Sendable {
    public let notifications: Int
    public let friends: Int
    public let expenses: Int
    public let messages: Int

    public init(notifications: Int, friends: Int, expenses: Int, messages: Int = 0) {
        self.notifications = max(0, notifications)
        self.friends = max(0, friends)
        self.expenses = max(0, expenses)
        self.messages = max(0, messages)
    }

    public static let zero = TabBadgeCounts(notifications: 0, friends: 0, expenses: 0, messages: 0)

    /// Matches notification-service badge `total` / APNS `aps.badge`.
    public var total: Int {
        notifications + friends + expenses + messages
    }

    /// Clears bell / friends / expenses "new" badges without touching unread message count.
    public func clearingUnseenInboxBadges() -> TabBadgeCounts {
        TabBadgeCounts(
            notifications: 0,
            friends: 0,
            expenses: 0,
            messages: messages
        )
    }
}
