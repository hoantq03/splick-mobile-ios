import Foundation

/// Posted when feed-related push arrives so the feed can force an ahead-count check (new-posts pill).
public enum FeedContentMayHaveChanged {
    public static let notification = Notification.Name("splick.feedContentMayHaveChanged")

    public static func post() {
        NotificationCenter.default.post(name: notification, object: nil)
    }
}

public extension Notification.Name {
    static let feedContentMayHaveChanged = FeedContentMayHaveChanged.notification
}
