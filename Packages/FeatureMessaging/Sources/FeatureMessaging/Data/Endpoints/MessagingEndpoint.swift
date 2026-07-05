import Foundation
import Networking

enum MessagingEndpoint: APIEndpoint {
    case listConversations(page: Int, limit: Int)
    case getOrCreateConversation(friendUserId: UUID)
    case createGroup(CreateGroupConversationRequestDTO)
    case addGroupMember(groupId: UUID, AddGroupMemberRequestDTO)
    case removeGroupMember(groupId: UUID, memberUserId: UUID)
    case leaveGroup(groupId: UUID)
    case renameGroup(groupId: UUID, RenameGroupRequestDTO)
    case transferGroupAdmin(groupId: UUID, TransferGroupAdminRequestDTO)
    case listMessages(conversationId: UUID, page: Int, limit: Int)
    case sendMessage(conversationId: UUID, body: String, clientMessageId: UUID)
    case markRead(conversationId: UUID, upToMessageId: UUID)
    case unreadCount
    case searchMessages(q: String, page: Int, limit: Int)
    case addReaction(conversationId: UUID, messageId: UUID, CreateReactionRequestDTO)
    case removeReaction(conversationId: UUID, messageId: UUID, reactionId: UUID)

    var path: String {
        switch self {
        case .listConversations, .getOrCreateConversation:
            return "/v1/messaging/conversations"
        case .createGroup:
            return "/v1/messaging/groups"
        case .addGroupMember(let groupId, _):
            return "/v1/messaging/groups/\(groupId)/members"
        case .removeGroupMember(let groupId, let memberUserId):
            return "/v1/messaging/groups/\(groupId)/members/\(memberUserId)"
        case .leaveGroup(let groupId):
            return "/v1/messaging/groups/\(groupId)/leave"
        case .renameGroup(let groupId, _):
            return "/v1/messaging/groups/\(groupId)/name"
        case .transferGroupAdmin(let groupId, _):
            return "/v1/messaging/groups/\(groupId)/admin"
        case .listMessages(let id, _, _):
            return "/v1/messaging/conversations/\(id)/messages"
        case .sendMessage(let id, _, _):
            return "/v1/messaging/conversations/\(id)/messages"
        case .markRead(let id, _):
            return "/v1/messaging/conversations/\(id)/read"
        case .unreadCount:
            return "/v1/messaging/unread-count"
        case .searchMessages:
            return "/v1/messaging/search"
        case .addReaction(let conversationId, let messageId, _):
            return "/v1/messaging/conversations/\(conversationId)/messages/\(messageId)/reactions"
        case .removeReaction(let conversationId, let messageId, let reactionId):
            return "/v1/messaging/conversations/\(conversationId)/messages/\(messageId)/reactions/\(reactionId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listConversations, .listMessages, .unreadCount, .searchMessages: return .get
        case .getOrCreateConversation, .sendMessage, .markRead, .addReaction, .createGroup, .addGroupMember: return .post
        case .removeReaction, .removeGroupMember, .leaveGroup: return .delete
        case .renameGroup: return .patch
        case .transferGroupAdmin: return .put
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
        case .searchMessages(let q, let page, let limit):
            return [
                URLQueryItem(name: "q", value: q),
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
        case .createGroup(let dto):
            return dto
        case .addGroupMember(_, let dto):
            return dto
        case .renameGroup(_, let dto):
            return dto
        case .transferGroupAdmin(_, let dto):
            return dto
        case .sendMessage(_, let msgBody, let clientId):
            return SendMessageRequestDTO(body: msgBody, clientMessageId: clientId)
        case .markRead(_, let messageId):
            return MarkReadRequestDTO(upToMessageId: messageId)
        case .addReaction(_, _, let dto):
            return dto
        default: return nil
        }
    }
}
