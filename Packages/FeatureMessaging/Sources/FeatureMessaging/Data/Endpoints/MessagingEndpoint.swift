import Foundation
import Networking

enum MessagingEndpoint: APIEndpoint {
    case listConversations(ConversationInboxQuery)
    case conversationInboxSummary
    case getOrCreateConversation(friendUserId: UUID)
    case createGroup(CreateGroupConversationRequestDTO)
    case addGroupMember(groupId: UUID, AddGroupMemberRequestDTO)
    case removeGroupMember(groupId: UUID, memberUserId: UUID)
    case leaveGroup(groupId: UUID)
    case deleteConversation(conversationId: UUID)
    case renameGroup(groupId: UUID, RenameGroupRequestDTO)
    case updateNotificationSettings(conversationId: UUID, UpdateConversationNotificationSettingsRequestDTO)
    case transferGroupAdmin(groupId: UUID, TransferGroupAdminRequestDTO)
    case listMessages(
        conversationId: UUID,
        page: Int,
        limit: Int,
        after: Int64?,
        before: Int64?
    )
    case sendMessage(
        conversationId: UUID,
        body: String,
        clientMessageId: UUID,
        attachments: [SendMessageRequestDTO.MessageAttachmentRequestDTO],
        replyToMessageId: UUID?
    )
    case markRead(conversationId: UUID, upToMessageId: UUID)
    case unreadCount
    case searchMessages(q: String, page: Int, limit: Int, conversationId: UUID?)
    case addReaction(conversationId: UUID, messageId: UUID, CreateReactionRequestDTO)
    case removeReaction(conversationId: UUID, messageId: UUID, reactionId: UUID)
    case wsTicket

    var path: String {
        switch self {
        case .listConversations, .getOrCreateConversation:
            return "/v1/messaging/conversations"
        case .conversationInboxSummary:
            return "/v1/messaging/conversations/summary"
        case .createGroup:
            return "/v1/messaging/groups"
        case .addGroupMember(let groupId, _):
            return "/v1/messaging/groups/\(groupId)/members"
        case .removeGroupMember(let groupId, let memberUserId):
            return "/v1/messaging/groups/\(groupId)/members/\(memberUserId)"
        case .leaveGroup(let groupId):
            return "/v1/messaging/groups/\(groupId)/leave"
        case .deleteConversation(let conversationId):
            return "/v1/messaging/conversations/\(conversationId)"
        case .renameGroup(let groupId, _):
            return "/v1/messaging/groups/\(groupId)/name"
        case .updateNotificationSettings(let conversationId, _):
            return "/v1/messaging/conversations/\(conversationId)/notification-settings"
        case .transferGroupAdmin(let groupId, _):
            return "/v1/messaging/groups/\(groupId)/admin"
        case .listMessages(let id, _, _, _, _):
            return "/v1/messaging/conversations/\(id)/messages"
        case .sendMessage(let id, _, _, _, _):
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
        case .wsTicket:
            return "/v1/messaging/ws-ticket"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listConversations, .listMessages, .unreadCount, .searchMessages, .conversationInboxSummary:
            return .get
        case .getOrCreateConversation, .sendMessage, .markRead, .addReaction, .createGroup, .addGroupMember, .wsTicket:
            return .post
        case .removeReaction, .removeGroupMember, .leaveGroup, .deleteConversation:
            return .delete
        case .renameGroup, .updateNotificationSettings:
            return .patch
        case .transferGroupAdmin:
            return .put
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .listConversations(let query):
            var items = [
                URLQueryItem(name: "page", value: "\(query.page)"),
                URLQueryItem(name: "limit", value: "\(query.limit)"),
            ]
            if let type = query.type {
                items.append(URLQueryItem(name: "type", value: type.rawValue))
            }
            if query.unreadOnly {
                items.append(URLQueryItem(name: "unreadOnly", value: "true"))
            }
            return items
        case .listMessages(_, let page, let limit, let after, let before):
            var items = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
            if let after {
                items.append(URLQueryItem(name: "after", value: "\(after)"))
            }
            if let before {
                items.append(URLQueryItem(name: "before", value: "\(before)"))
            }
            return items
        case .searchMessages(let q, let page, let limit, let conversationId):
            var items = [
                URLQueryItem(name: "q", value: q),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
            if let conversationId {
                items.append(URLQueryItem(name: "conversationId", value: conversationId.uuidString))
            }
            return items
        default:
            return nil
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
        case .updateNotificationSettings(_, let dto):
            return dto
        case .transferGroupAdmin(_, let dto):
            return dto
        case .sendMessage(_, let msgBody, let clientId, let attachments, let replyToMessageId):
            return SendMessageRequestDTO(
                body: msgBody,
                clientMessageId: clientId,
                attachments: attachments.isEmpty ? nil : attachments,
                replyToMessageId: replyToMessageId
            )
        case .markRead(_, let messageId):
            return MarkReadRequestDTO(upToMessageId: messageId)
        case .addReaction(_, _, let dto):
            return dto
        default:
            return nil
        }
    }
}
