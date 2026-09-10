import Foundation

/// Posted when expenses, settlements, or payment evidence change so the Chi tiêu tab can reload.
public enum ExpensesDirectoryChange {
    public static let notification = Notification.Name("splick.expensesDirectoryDidChange")

    public static func post() {
        NotificationCenter.default.post(name: notification, object: nil)
    }
}
