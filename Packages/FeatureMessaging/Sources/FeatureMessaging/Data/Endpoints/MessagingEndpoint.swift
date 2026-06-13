import Foundation
import Networking

enum MessagingEndpoint: APIEndpoint {
    case listConversations(page: Int, limit: Int)
    case getOrCreateConversation(friendUserId: UUID)
    case listMessages(conversationId: UUID, page: Int, limit: Int)
    case sendMessage(conversationId: UUID, body: String, clientMessageId: UUID)
    case markRead(conversationId: UUID, upToMessageId: UUID)
    case unreadCount

    var path: String {
        switch self {
        case .listConversations, .getOrCreateConversation:
            return "/v1/messaging/conversations"
        case .listMessages(let id, _, _):
            return "/v1/messaging/conversations/\(id)/messages"
        case .sendMessage(let id, _, _):
            return "/v1/messaging/conversations/\(id)/messages"
        case .markRead(let id, _):
            return "/v1/messaging/conversations/\(id)/read"
        case .unreadCount:
            return "/v1/messaging/unread-count"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listConversations, .listMessages, .unreadCount: return .get
        case .getOrCreateConversation, .sendMessage, .markRead: return .post
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .listConversations(let page, let limit):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
        case .listMessages(_, let page, let limit):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
        default: return nil
        }
    }

    var body: Encodable? {
        switch self {
        case .getOrCreateConversation(let friendUserId):
            return CreateConversationRequestDTO(friendUserId: friendUserId)
        case .sendMessage(_, let msgBody, let clientId):
            return SendMessageRequestDTO(body: msgBody, clientMessageId: clientId)
        case .markRead(_, let messageId):
            return MarkReadRequestDTO(upToMessageId: messageId)
        default: return nil
        }
    }
}
