import Foundation
import Networking
import SplickDomain

protocol SplickStickerDataSourceProtocol: Sendable {
    func fetchStickers(groupId: UUID, keyword: String) async throws -> [Sticker]
}

final class SplickStickerDataSource: SplickStickerDataSourceProtocol, Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func fetchStickers(groupId: UUID, keyword: String) async throws -> [Sticker] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let dtos: [SplickStickerDTO] = try await apiClient.request(
            StickerEndpoint.groupStickers(
                groupId: groupId,
                keyword: trimmed.isEmpty ? nil : trimmed
            )
        )
        return dtos.compactMap { StickerMapper.toSticker($0, groupId: groupId) }
    }
}
