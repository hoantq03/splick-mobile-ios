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
}
