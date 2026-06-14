import Foundation
import SplickDomain

public protocol MessagingRepositoryProtocol: Sendable {
    func fetchConversations(page: Int, limit: Int) async throws -> [Conversation]
    func getOrCreateConversation(friendUserId: UUID) async throws -> Conversation
    func fetchMessages(conversationId: UUID, page: Int, limit: Int) async throws -> [ChatMessage]
    func sendMessage(conversationId: UUID, body: String, clientMessageId: UUID) async throws -> ChatMessage
    func markRead(conversationId: UUID, upToMessageId: UUID) async throws
    func unreadCount() async throws -> Int
    func addReaction(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction
    func removeReaction(conversationId: UUID, messageId: UUID, reactionId: UUID) async throws
    func searchMessages(query: String, page: Int, limit: Int) async throws -> [MessageSearchHit]
}
