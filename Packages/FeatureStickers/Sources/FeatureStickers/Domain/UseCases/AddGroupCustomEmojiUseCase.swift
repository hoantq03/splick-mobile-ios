import Foundation
import SplickDomain

public protocol AddUserCustomEmojiUseCaseProtocol: Sendable {
    func execute(alias: String?, mediaId: UUID) async throws -> CustomEmoji
}

public final class AddUserCustomEmojiUseCase: AddUserCustomEmojiUseCaseProtocol, Sendable {
    private let repository: CustomEmojiRepositoryProtocol

    public init(repository: CustomEmojiRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(alias: String?, mediaId: UUID) async throws -> CustomEmoji {
        try await repository.addEmoji(alias: alias, mediaId: mediaId)
    }
}
