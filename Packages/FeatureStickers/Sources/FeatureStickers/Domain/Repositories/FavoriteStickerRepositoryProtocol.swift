import Foundation
import SplickDomain

public protocol FavoriteStickerRepositoryProtocol: Sendable {
    func fetchFavorites() async throws -> [Sticker]
    func addFavorite(
        provider: String,
        externalId: String,
        url: URL,
        previewURL: URL?,
        name: String?
    ) async throws
    func removeFavorite(id: UUID) async throws
}
