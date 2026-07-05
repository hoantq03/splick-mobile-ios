import Foundation

public enum NotificationNavigationTarget: Equatable, Sendable {
    case post(UUID)
    case feed
    case expenses
    case friends
    case messages
    case inbox
    case none
}
