import Foundation
import FeatureMessaging
import FeatureNotification
import Networking
import SplickDomain

public protocol AppStartupRepositoryProtocol: Sendable {
    func fetchStartupData() async throws -> AppStartupData
    func loadCached(userId: UUID) async -> AppStartupData?
    func saveCached(_ data: AppStartupData, userId: UUID) async
}

public final class AppStartupRepository: AppStartupRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func fetchStartupData() async throws -> AppStartupData {
        let dto: StartupDataResponseDTO = try await apiClient.request(AppStartupEndpoint.startup)
        return map(dto)
    }

    private func map(_ dto: StartupDataResponseDTO) -> AppStartupData {
        AppStartupData(
            badgeCounts: TabBadgeCounts(
                notifications: dto.badgeCounts.notifications,
                friends: dto.badgeCounts.friends,
                expenses: dto.badgeCounts.expenses,
                messages: dto.badgeCounts.messages
            ),
            posts: dto.feedFirstPage.map(FeedMapper.toPost),
            conversations: dto.conversations.map(mapConversation),
            emojis: dto.customEmojis.compactMap(mapEmoji),
            currentStreak: dto.currentStreak,
            hasTodayPhoto: dto.hasTodayPhoto
        )
    }

    private func mapConversation(_ dto: StartupConversationDTO) -> Conversation {
        let type = ConversationType(rawValue: dto.type ?? ConversationType.direct.rawValue) ?? .direct
        return Conversation(
            id: dto.id,
            type: type,
            unreadCount: dto.unreadCount,
            peer: dto.peer.map {
                ConversationPeer(
                    userId: $0.userId,
                    username: $0.username,
                    displayName: $0.displayName,
                    avatarUrl: $0.avatarUrl
                )
            },
            groupName: dto.groupName,
            groupAvatarUrl: dto.groupAvatarUrl,
            memberCount: dto.memberCount,
            lastMessage: dto.lastMessage.map(mapMessage),
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    private func mapMessage(_ dto: StartupMessageDTO) -> ChatMessage {
        ChatMessage(
            id: dto.id,
            conversationId: dto.conversationId,
            senderId: dto.senderId,
            body: dto.body,
            clientMessageId: dto.clientMessageId ?? dto.id,
            createdAt: dto.createdAt,
            reactions: (dto.reactions ?? []).map {
                Reaction(id: $0.id, emoji: $0.emoji, userId: $0.userId, createdAt: $0.createdAt)
            }
        )
    }

    private func mapEmoji(_ dto: StartupCustomEmojiDTO) -> CustomEmoji? {
        guard let url = URL(string: dto.mediaUrl) else { return nil }
        return CustomEmoji(
            id: dto.id,
            ownerId: dto.ownerId ?? UUID(),
            shortcode: dto.shortcode,
            mediaUrl: url,
            createdAt: dto.createdAt
        )
    }
}
