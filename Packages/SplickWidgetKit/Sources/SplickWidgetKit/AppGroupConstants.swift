import Foundation

public enum WidgetAppGroup {
    public static let identifier = "group.com.splick.app"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    public static var cacheDirectoryURL: URL? {
        containerURL?.appendingPathComponent("WidgetCache", isDirectory: true)
    }

    public static var imageCacheDirectoryURL: URL? {
        containerURL?.appendingPathComponent("WidgetImages", isDirectory: true)
    }
}

public enum WidgetCacheFile {
    public static let expenseSummary = "expense_summary.json"
    public static let messagingInbox = "messaging_inbox.json"
    public static let latestFriendPhoto = "latest_friend_photo.json"
    public static let streak = "streak.json"
    public static let friendRequests = "friend_requests.json"
    public static let groups = "groups.json"

    public static func groupExpense(groupId: UUID) -> String {
        "group_expense_\(groupId.uuidString.lowercased()).json"
    }
}

public enum WidgetKind {
    public static let expenseSummary = "ExpenseSummaryWidget"
    public static let unreadMessages = "UnreadMessagesWidget"
    public static let latestFriendPhoto = "LatestFriendPhotoWidget"
    public static let friendStreak = "FriendStreakWidget"
    public static let quickCapture = "QuickCaptureWidget"
    public static let friendRequest = "FriendRequestWidget"
    public static let groupExpense = "GroupExpenseWidget"
}
