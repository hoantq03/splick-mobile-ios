import Foundation
import SplickDomain

public protocol FetchStickersUseCaseProtocol: Sendable {
    func execute(query: String, source: StickerSource) async throws -> [Sticker]
}

public final class FetchStickersUseCase: FetchStickersUseCaseProtocol, Sendable {
    private let repository: StickerRepositoryProtocol

    public init(repository: StickerRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(query: String, source: StickerSource) async throws -> [Sticker] {
        try await repository.fetchStickers(query: query, source: source)
    }
}
