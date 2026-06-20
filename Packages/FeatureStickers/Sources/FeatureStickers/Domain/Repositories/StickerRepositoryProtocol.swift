import Foundation
import SplickDomain

public protocol StickerRepositoryProtocol: Sendable {
    func fetchStickers(query: String, source: StickerSource) async throws -> [Sticker]
}
