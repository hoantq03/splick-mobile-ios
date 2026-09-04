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
    func execute(sticker: Sticker, name: String?) async throws -> Sticker
}

public final class AddFavoriteStickerUseCase: AddFavoriteStickerUseCaseProtocol, Sendable {
    private let repository: FavoriteStickerRepositoryProtocol

    public init(repository: FavoriteStickerRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(sticker: Sticker, name: String?) async throws -> Sticker {
        let provider: String
        switch sticker.source {
        case .klipy:
            provider = "klipy"
        case .custom:
            provider = "custom"
        }

        return try await repository.addFavorite(
            provider: provider,
            externalId: sticker.id,
            url: sticker.url,
            previewURL: sticker.previewURL,
            name: name,
            width: sticker.width,
            height: sticker.height
        )
    }
}

public protocol RemoveFavoriteStickerUseCaseProtocol: Sendable {
    func execute(favoriteId: UUID) async throws
}

public final class RemoveFavoriteStickerUseCase: RemoveFavoriteStickerUseCaseProtocol, Sendable {
    private let repository: FavoriteStickerRepositoryProtocol

    public init(repository: FavoriteStickerRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(favoriteId: UUID) async throws {
        try await repository.removeFavorite(id: favoriteId)
    }
}
