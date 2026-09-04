import Foundation

public enum NotificationNavigationTarget: Equatable, Sendable {
    case post(UUID, commentId: UUID? = nil)
    case feed
    case expenses
    case friends
    case messages
    case conversation(UUID, highlightMessageId: UUID? = nil)
    case userProfile(UUID)
    case inbox
    case none
}
