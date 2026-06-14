import Foundation
import Networking
import SplickDomain

public final class MessagingRepository: MessagingRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func fetchConversations(page: Int, limit: Int) async throws -> [Conversation] {
        let dtos: [ConversationResponseDTO] = try await apiClient.request(
            MessagingEndpoint.listConversations(page: page, limit: limit)
        )
        return dtos.map(MessagingMapper.toConversation)
    }

    public func getOrCreateConversation(friendUserId: UUID) async throws -> Conversation {
        let dto: ConversationResponseDTO = try await apiClient.request(
            MessagingEndpoint.getOrCreateConversation(friendUserId: friendUserId)
        )
        return MessagingMapper.toConversation(dto)
    }

    public func fetchMessages(conversationId: UUID, page: Int, limit: Int) async throws -> [ChatMessage] {
        let dtos: [MessageResponseDTO] = try await apiClient.request(
            MessagingEndpoint.listMessages(conversationId: conversationId, page: page, limit: limit)
        )
        return dtos.map(MessagingMapper.toMessage)
    }

    public func sendMessage(conversationId: UUID, body: String, clientMessageId: UUID) async throws -> ChatMessage {
        let dto: MessageResponseDTO = try await apiClient.request(
            MessagingEndpoint.sendMessage(conversationId: conversationId, body: body, clientMessageId: clientMessageId)
        )
        return MessagingMapper.toMessage(dto)
    }

    public func markRead(conversationId: UUID, upToMessageId: UUID) async throws {
        try await apiClient.request(
            MessagingEndpoint.markRead(conversationId: conversationId, upToMessageId: upToMessageId)
        )
    }

    public func unreadCount() async throws -> Int {
        let dto: UnreadMessageCountDTO = try await apiClient.request(MessagingEndpoint.unreadCount)
        return dto.unreadCount
    }

    public func addReaction(conversationId: UUID, messageId: UUID, emoji: String) async throws -> Reaction {
        let dto: ReactionResponseDTO = try await apiClient.request(
            MessagingEndpoint.addReaction(
                conversationId: conversationId,
                messageId: messageId,
                CreateReactionRequestDTO(emoji: emoji)
            )
        )
        return MessagingMapper.toReaction(dto)
    }

    public func removeReaction(conversationId: UUID, messageId: UUID, reactionId: UUID) async throws {
        try await apiClient.request(
            MessagingEndpoint.removeReaction(
                conversationId: conversationId,
                messageId: messageId,
                reactionId: reactionId
            )
        )
    }
}
