import Foundation

/// Pauses parent scroll views while reaction trays or drag pickers are active.
public enum InteractionScrollLock {
    public static let notification = Notification.Name("splick.interactionScrollLockChanged")

    public static func setLocked(_ locked: Bool) {
        NotificationCenter.default.post(
            name: notification,
            object: nil,
            userInfo: ["locked": locked]
        )
    }

    public static func forceUnlock() {
        setLocked(false)
    }
}
