import Foundation
import Networking

enum NotificationEndpoint: APIEndpoint {
    case list(page: Int, limit: Int)
    case markRead(id: UUID)
    case markAllRead
    case unreadCount

    var path: String {
        switch self {
        case .list: return "/v1/notifications"
        case .markRead(let id): return "/v1/notifications/\(id)/read"
        case .markAllRead: return "/v1/notifications/read-all"
        case .unreadCount: return "/v1/notifications/unread-count"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .unreadCount: return .get
        case .markRead, .markAllRead: return .post
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
