import Foundation

/// Posted when friendships or friend requests change so the friends directory can reload.
public enum FriendshipsDirectoryChange {
    public static let notification = Notification.Name("splick.friendshipsDirectoryDidChange")

    public static func post() {
        NotificationCenter.default.post(name: notification, object: nil)
    }
}
