import Foundation
import Common

public extension Notification.Name {
    /// Posted when friendships or friend requests change outside the Friends tab
    /// (e.g. push, notification inbox Accept/Reject).
    static let friendshipsDirectoryDidChange = FriendshipsDirectoryChange.notification
}
