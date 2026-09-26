import Foundation

public extension Notification.Name {
    /// Posted when groups are created or joined outside the Friends tab (e.g. messaging compose).
    static let groupsDirectoryDidChange = Notification.Name("splick.groupsDirectoryDidChange")
}
