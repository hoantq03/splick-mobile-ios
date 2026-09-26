import Foundation
import SplickDomain

public protocol FavoriteStickerRepositoryProtocol: Sendable {
    func fetchFavorites() async throws -> [Sticker]
    func addFavorite(
        provider: String,
        externalId: String,
        url: URL,
        previewURL: URL?,
        name: String?,
        width: Int?,
        height: Int?
    ) async throws -> Sticker
    func removeFavorite(id: UUID) async throws
}
