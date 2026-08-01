import Foundation
import Networking
import SplickDomain

public final class MessagingRepository: MessagingRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func fetchConversations(query: ConversationInboxQuery) async throws -> MessagingPage<Conversation> {
        let page: PageResponseDTO<ConversationResponseDTO> = try await apiClient.request(
            MessagingEndpoint.listConversations(query)
        )
        return MessagingPage(
            items: page.items.map(MessagingMapper.toConversation),
            nextCursor: page.nextCursor,
            hasMore: page.hasMore
        )
    }

    public func fetchConversationInboxSummary() async throws -> Int {
        let dto: ConversationInboxSummaryResponseDTO = try await apiClient.request(
            MessagingEndpoint.conversationInboxSummary
        )
        return dto.unreadConversationCount
    }

    public func getOrCreateConversation(friendUserId: UUID) async throws -> Conversation {
        let dto: ConversationResponseDTO = try await apiClient.request(
            MessagingEndpoint.getOrCreateConversation(friendUserId: friendUserId)
        )
        return MessagingMapper.toConversation(dto)
    }

    public func createGroup(
        name: String,
        avatarUrl: String?,
        memberUserIds: [UUID],
        groupId: UUID?
    ) async throws -> Conversation {
        let dto: ConversationResponseDTO = try await apiClient.request(
            MessagingEndpoint.createGroup(
                CreateGroupConversationRequestDTO(
                    groupId: groupId,
                    name: name,
                    avatarUrl: avatarUrl,
                    memberUserIds: memberUserIds
                )
            )
        )
        return MessagingMapper.toConversation(dto)
    }

    public func addGroupMember(groupId: UUID, memberUserId: UUID) async throws {
        try await apiClient.request(
            MessagingEndpoint.addGroupMember(
                groupId: groupId,
                AddGroupMemberRequestDTO(memberUserId: memberUserId)
            )
        )
    }

    public func removeGroupMember(groupId: UUID, memberUserId: UUID) async throws {
        try await apiClient.request(
            MessagingEndpoint.removeGroupMember(groupId: groupId, memberUserId: memberUserId)
        )
    }

    public func leaveGroup(groupId: UUID) async throws {
        try await apiClient.request(MessagingEndpoint.leaveGroup(groupId: groupId))
    }

    public func renameGroup(groupId: UUID, name: String) async throws -> Conversation {
        let dto: ConversationResponseDTO = try await apiClient.request(
            MessagingEndpoint.renameGroup(groupId: groupId, RenameGroupRequestDTO(name: name))
        )
        return MessagingMapper.toConversation(dto)
    }

    public func transferGroupAdmin(groupId: UUID, newAdminUserId: UUID) async throws {
        try await apiClient.request(
            MessagingEndpoint.transferGroupAdmin(
                groupId: groupId,
                TransferGroupAdminRequestDTO(newAdminUserId: newAdminUserId)
            )
        )
    }

    public func fetchMessages(
        conversationId: UUID,
        page: Int,
        limit: Int,
        after: Int64?,
        before: Int64?
    ) async throws -> MessagingPage<ChatMessage> {
        let pageDTO: PageResponseDTO<MessageResponseDTO> = try await apiClient.request(
            MessagingEndpoint.listMessages(
                conversationId: conversationId,
                page: page,
                limit: limit,
                after: after,
                before: before
            )
        )
        return MessagingPage(
            items: pageDTO.items.map(MessagingMapper.toMessage),
            nextCursor: pageDTO.nextCursor,
            hasMore: pageDTO.hasMore
        )
    }

    public func sendMessage(
        conversationId: UUID,
        body: String,
        clientMessageId: UUID,
        imageAttachments: [MessageImageAttachment] = [],
        replyToMessageId: UUID? = nil
    ) async throws -> ChatMessage {
        let attachmentDTOs = imageAttachments.map {
            SendMessageRequestDTO.MessageAttachmentRequestDTO(
                mediaId: $0.mediaId,
                url: $0.url.absoluteString,
                thumbnailUrl: $0.thumbnailURL?.absoluteString
            )
        }
        let dto: MessageResponseDTO = try await apiClient.request(
            MessagingEndpoint.sendMessage(
                conversationId: conversationId,
                body: body,
                clientMessageId: clientMessageId,
                attachments: attachmentDTOs,
                replyToMessageId: replyToMessageId
            )
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

    public func searchMessages(query: String, page: Int, limit: Int) async throws -> [MessageSearchHit] {
        let dtos: [MessageSearchHitResponseDTO] = try await apiClient.request(
            MessagingEndpoint.searchMessages(q: query, page: page, limit: limit)
        )
        return dtos.compactMap(MessagingMapper.toMessageSearchHit)
    }

    public func requestWsTicket() async throws -> String {
        let dto: WsTicketResponseDTO = try await apiClient.request(MessagingEndpoint.wsTicket)
        return dto.ticket
    }
}
