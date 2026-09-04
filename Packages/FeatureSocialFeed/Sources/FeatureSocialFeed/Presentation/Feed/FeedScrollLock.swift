import Foundation
import Common

/// Posted when the Facebook-style reaction tray opens/closes so the feed can pause scrolling.
enum FeedScrollLock {
    static let notification = InteractionScrollLock.notification

    static func setLocked(_ locked: Bool) {
        InteractionScrollLock.setLocked(locked)
    }

    static func forceUnlock() {
        InteractionScrollLock.forceUnlock()
    }
}
