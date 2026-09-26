import Foundation

/// Posted when messaging-related push arrives so the inbox can soft-refresh (filters + unread).
public enum MessagingInboxMayHaveChanged {
    public static let notification = Notification.Name("splick.messagingInboxMayHaveChanged")

    public static func post() {
        NotificationCenter.default.post(name: notification, object: nil)
    }
}

public extension Notification.Name {
    static let messagingInboxMayHaveChanged = MessagingInboxMayHaveChanged.notification
}
