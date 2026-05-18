import Foundation

/// Posted when the Facebook-style reaction tray opens/closes so the feed can pause scrolling.
enum FeedScrollLock {
    static let notification = Notification.Name("splick.feedScrollLockChanged")

    static func setLocked(_ locked: Bool) {
        NotificationCenter.default.post(
            name: notification,
            object: nil,
            userInfo: ["locked": locked]
        )
    }
}
