import Foundation

/// Home-screen widgets exposed by `SplickWidgetExtension`.
public enum HomeScreenWidget: String, CaseIterable, Identifiable, Sendable {
    case expenseSummary
    case unreadMessages
    case latestFriendPhoto
    case friendStreak
    case quickCapture
    case friendRequest
    case groupExpense

    public var id: String { kind }

    public var kind: String {
        switch self {
        case .expenseSummary: return WidgetKind.expenseSummary
        case .unreadMessages: return WidgetKind.unreadMessages
        case .latestFriendPhoto: return WidgetKind.latestFriendPhoto
        case .friendStreak: return WidgetKind.friendStreak
        case .quickCapture: return WidgetKind.quickCapture
        case .friendRequest: return WidgetKind.friendRequest
        case .groupExpense: return WidgetKind.groupExpense
        }
    }

    public var systemImage: String {
        switch self {
        case .expenseSummary: return "banknote"
        case .unreadMessages: return "message.fill"
        case .latestFriendPhoto: return "photo.on.rectangle.angled"
        case .friendStreak: return "flame.fill"
        case .quickCapture: return "camera.fill"
        case .friendRequest: return "person.badge.plus"
        case .groupExpense: return "person.3.fill"
        }
    }
}
