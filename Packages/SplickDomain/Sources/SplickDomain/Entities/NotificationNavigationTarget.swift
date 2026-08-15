import Foundation

public enum NotificationNavigationTarget: Equatable, Sendable {
    case post(UUID)
    case feed
    case expenses
    case friends
    case messages
    case conversation(UUID, highlightMessageId: UUID? = nil)
    case userProfile(UUID)
    case inbox
    case none
}
