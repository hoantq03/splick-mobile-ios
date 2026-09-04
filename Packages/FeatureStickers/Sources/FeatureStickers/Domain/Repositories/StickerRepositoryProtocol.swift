import Foundation
import SplickDomain

public protocol StickerRepositoryProtocol: Sendable {
    func fetchStickers(
        query: String,
        source: StickerSource,
        position: String?
    ) async throws -> StickerFetchResult
}
