import Foundation

public struct TabBadgeCounts: Equatable, Sendable {
    public let notifications: Int
    public let friends: Int
    public let expenses: Int

    public init(notifications: Int, friends: Int, expenses: Int) {
        self.notifications = max(0, notifications)
        self.friends = max(0, friends)
        self.expenses = max(0, expenses)
    }

    public static let zero = TabBadgeCounts(notifications: 0, friends: 0, expenses: 0)
}
