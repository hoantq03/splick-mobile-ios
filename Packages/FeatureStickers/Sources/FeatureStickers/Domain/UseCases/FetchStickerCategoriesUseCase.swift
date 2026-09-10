import Foundation
import SplickDomain

public protocol FetchStickerCategoriesUseCaseProtocol: Sendable {
    func execute() async throws -> [StickerCategory]
}

public final class FetchStickerCategoriesUseCase: FetchStickerCategoriesUseCaseProtocol, Sendable {
    private let repository: KlipyMetaRepositoryProtocol

    public init(repository: KlipyMetaRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [StickerCategory] {
        try await repository.fetchCategories()
    }
}
