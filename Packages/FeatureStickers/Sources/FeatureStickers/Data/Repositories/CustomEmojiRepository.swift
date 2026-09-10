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

    public func fetchAllEmojis() async throws -> [CustomEmoji] {
        let dtos: [CustomEmojiResponseDTO] = try await apiClient.request(CustomEmojiEndpoint.listAll)
        return dtos.compactMap { CustomEmojiMapper.toDomain($0) }
    }

    public func fetchMyEmojis() async throws -> [CustomEmoji] {
        let dtos: [CustomEmojiResponseDTO] = try await apiClient.request(CustomEmojiEndpoint.listMine)
        return dtos.compactMap { CustomEmojiMapper.toDomain($0) }
    }

    public func addEmoji(alias: String?, mediaId: UUID) async throws -> CustomEmoji {
        let dto: CustomEmojiResponseDTO = try await apiClient.request(
            CustomEmojiEndpoint.create(request: CreateCustomEmojiRequestDTO(alias: alias, mediaId: mediaId))
        )
        guard let emoji = CustomEmojiMapper.toDomain(dto) else {
            throw CustomEmojiError.invalidResponse
        }
        return emoji
    }

    public func deleteEmoji(emojiId: UUID) async throws {
        try await apiClient.request(CustomEmojiEndpoint.delete(emojiId: emojiId))
    }
}
