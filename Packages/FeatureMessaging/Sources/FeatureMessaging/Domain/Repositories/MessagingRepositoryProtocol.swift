import Foundation
import SplickDomain

public protocol MessagingRepositoryProtocol: Sendable {
    func fetchConversations(query: ConversationInboxQuery) async throws -> [Conversation]
    func fetchConversationInboxSummary() async throws -> Int
    func getOrCreateConversation(friendUserId: UUID) async throws -> Conversation
    func createGroup(
        name: String,
        avatarUrl: String?,
        memberUserIds: [UUID],
        groupId: UUID?
    ) async throws -> Conversation
    func addGroupMember(groupId: UUID, memberUserId: UUID) async throws
    func removeGroupMember(groupId: UUID, memberUserId: UUID) async throws
    func leaveGroup(groupId: UUID) async throws
    func renameGroup(groupId: UUID, name: String) async throws -> Conversation
    func transferGroupAdmin(groupId: UUID, newAdminUserId: UUID) async throws
    func fetchMessages(conversationId: UUID, page: Int, limit: Int) async throws -> [ChatMessage]
    func sendMessage(
        conversationId: UUID,
        body: String,
        clientMessageId: UUID,
        imageAttachments: [MessageImageAttachment],
        replyToMessageId: UUID?
    ) async throws -> ChatMessage
    func markRead(conversationId: UUID, upToMessageId: UUID) async throws
    func unreadCount() async throws -> Int
    func addReaction(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction
    func removeReaction(conversationId: UUID, messageId: UUID, reactionId: UUID) async throws
    func searchMessages(query: String, page: Int, limit: Int) async throws -> [MessageSearchHit]
}

public extension MessagingRepositoryProtocol {
    func fetchConversations(page: Int, limit: Int) async throws -> [Conversation] {
        try await fetchConversations(
            query: ConversationInboxQuery(page: page, limit: limit)
        )
    }
}

public extension MessagingRepositoryProtocol {
    func createGroup(
        name: String,
        avatarUrl: String?,
        memberUserIds: [UUID]
    ) async throws -> Conversation {
        try await createGroup(
            name: name,
            avatarUrl: avatarUrl,
            memberUserIds: memberUserIds,
            groupId: nil
        )
    }

    func sendMessage(
        conversationId: UUID,
        body: String,
        clientMessageId: UUID,
        imageAttachments: [MessageImageAttachment] = []
    ) async throws -> ChatMessage {
        try await sendMessage(
            conversationId: conversationId,
            body: body,
            clientMessageId: clientMessageId,
            imageAttachments: imageAttachments,
            replyToMessageId: nil
        )
    }
}
