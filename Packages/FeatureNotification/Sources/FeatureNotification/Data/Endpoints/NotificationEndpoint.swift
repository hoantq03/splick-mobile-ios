import Foundation
import Networking

enum NotificationEndpoint: APIEndpoint {
    case list(page: Int, limit: Int)
    case markRead(id: UUID)
    case markClicked(id: UUID)
    case markAllRead
    case unreadCount
    case badgeCounts

    var path: String {
        switch self {
        case .list: return "/v1/notifications"
        case .markRead(let id): return "/v1/notifications/\(id)/read"
        case .markClicked(let id): return "/v1/notifications/\(id)/click"
        case .markAllRead: return "/v1/notifications/read-all"
        case .unreadCount: return "/v1/notifications/unread-count"
        case .badgeCounts: return "/v1/notifications/badge-counts"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .unreadCount, .badgeCounts: return .get
        case .markRead, .markAllRead, .markClicked: return .post
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .list(let page, let limit):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
        default: return nil
        }
    }
}
