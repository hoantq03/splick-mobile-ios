import Foundation
import Common
import Networking
import SplickDomain

public protocol CustomEmojiRepositoryProtocol: CustomEmojiFetching, Sendable {}

public final class CustomEmojiRepository: CustomEmojiRepositoryProtocol {
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func fetchEmojis(groupId: UUID) async throws -> [CustomEmoji] {
        let dtos: [CustomEmojiResponseDTO] = try await apiClient.request(
            CustomEmojiEndpoint.list(groupId: groupId)
        )
        return dtos.compactMap { CustomEmojiMapper.toDomain($0, groupId: groupId) }
    }

    public func addEmoji(groupId: UUID, shortcode: String, mediaId: UUID) async throws -> CustomEmoji {
        let dto: CustomEmojiResponseDTO = try await apiClient.request(
            CustomEmojiEndpoint.create(
                groupId: groupId,
                request: CreateCustomEmojiRequestDTO(shortcode: shortcode, mediaId: mediaId)
            )
        )
        guard let emoji = CustomEmojiMapper.toDomain(dto, groupId: groupId) else {
            throw CustomEmojiError.invalidResponse
        }
        return emoji
    }

    public func deleteEmoji(groupId: UUID, emojiId: UUID) async throws {
        try await apiClient.request(CustomEmojiEndpoint.delete(groupId: groupId, emojiId: emojiId))
    }
}
