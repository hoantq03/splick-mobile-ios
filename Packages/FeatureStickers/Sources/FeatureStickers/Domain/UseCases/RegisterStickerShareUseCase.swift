import Foundation

public protocol RegisterStickerShareUseCaseProtocol: Sendable {
    func execute(gifId: String, searchQuery: String?) async
}

public final class RegisterStickerShareUseCase: RegisterStickerShareUseCaseProtocol, Sendable {
    private let repository: KlipyMetaRepositoryProtocol

    public init(repository: KlipyMetaRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(gifId: String, searchQuery: String?) async {
        try? await repository.registerShare(gifId: gifId, searchQuery: searchQuery)
    }
}
