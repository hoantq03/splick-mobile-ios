import Foundation
import SplickDomain

public protocol MessagingRepositoryProtocol: Sendable {
    func fetchConversations(query: ConversationInboxQuery) async throws -> MessagingPage<Conversation>
    func fetchConversationInboxSummary() async throws -> Int
    func getOrCreateConversation(friendUserId: UUID) async throws -> Conversation
    func createGroup(
        name: String,
        avatarUrl: String?,
        memberUserIds: [UUID],
        groupId: UUID?
    ) async throws -> Conversation
    func addGroupMember(groupId: UUID, memberUserId: UUID, shareChatHistory: Bool) async throws
    func listGroupMembers(groupId: UUID) async throws -> [GroupChatMember]
    func removeGroupMember(groupId: UUID, memberUserId: UUID) async throws
    func leaveGroup(groupId: UUID) async throws
    func deleteConversation(conversationId: UUID) async throws
    func updateNotificationSettings(
        conversationId: UUID,
        notificationsEnabled: Bool,
        notificationSound: String
    ) async throws -> Conversation
    func renameGroup(groupId: UUID, name: String) async throws -> Conversation
    func updateGroupAvatar(groupId: UUID, avatarUrl: String) async throws -> Conversation
    func transferGroupAdmin(groupId: UUID, newAdminUserId: UUID) async throws
    func fetchMessages(
        conversationId: UUID,
        page: Int,
        limit: Int,
        after: Int64?,
        before: Int64?
    ) async throws -> MessagingPage<ChatMessage>
    func sendMessage(
        conversationId: UUID,
        body: String,
        clientMessageId: UUID,
        imageAttachments: [MessageImageAttachment],
        replyToMessageId: UUID?
    ) async throws -> ChatMessage
    func editMessage(conversationId: UUID, messageId: UUID, body: String) async throws -> ChatMessage
    func recallMessage(conversationId: UUID, messageId: UUID) async throws
    func markRead(conversationId: UUID, upToMessageId: UUID) async throws
    func unreadCount() async throws -> Int
    func addReaction(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction
    func removeReaction(conversationId: UUID, messageId: UUID, reactionId: UUID) async throws
    func searchMessages(
        query: String,
        page: Int,
        limit: Int,
        conversationId: UUID?
    ) async throws -> [MessageSearchHit]
    func requestWsTicket() async throws -> String
}

public extension MessagingRepositoryProtocol {
    func fetchConversations(page: Int, limit: Int) async throws -> MessagingPage<Conversation> {
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

    func searchMessages(
        query: String,
        page: Int = 0,
        limit: Int = 20
    ) async throws -> [MessageSearchHit] {
        try await searchMessages(
            query: query,
            page: page,
            limit: limit,
            conversationId: nil
        )
    }
}
