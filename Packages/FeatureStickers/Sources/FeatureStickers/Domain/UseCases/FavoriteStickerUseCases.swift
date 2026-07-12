import Foundation
import SplickDomain

public protocol FetchFavoriteStickersUseCaseProtocol: Sendable {
    func execute() async throws -> [Sticker]
}

public final class FetchFavoriteStickersUseCase: FetchFavoriteStickersUseCaseProtocol, Sendable {
    private let repository: FavoriteStickerRepositoryProtocol

    public init(repository: FavoriteStickerRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [Sticker] {
        try await repository.fetchFavorites()
    }
}

public protocol AddFavoriteStickerUseCaseProtocol: Sendable {
    func execute(sticker: Sticker, name: String?) async throws
}

public final class AddFavoriteStickerUseCase: AddFavoriteStickerUseCaseProtocol, Sendable {
    private let repository: FavoriteStickerRepositoryProtocol

    public init(repository: FavoriteStickerRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(sticker: Sticker, name: String?) async throws {
        let provider: String
        switch sticker.source {
        case .klipy:
            provider = "klipy"
        case .custom:
            provider = "custom"
        }

        try await repository.addFavorite(
            provider: provider,
            externalId: sticker.id,
            url: sticker.url,
            previewURL: sticker.previewURL,
            name: name
        )
    }
}
