import Foundation

/// Posted when social group membership changes so the friends directory can reload.
public enum GroupsDirectoryChange {
    public static let notification = Notification.Name("splick.groupsDirectoryDidChange")

    public static func post() {
        NotificationCenter.default.post(name: notification, object: nil)
    }
}
