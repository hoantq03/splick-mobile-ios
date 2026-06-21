import Foundation
import SplickDomain

public protocol AddGroupCustomEmojiUseCaseProtocol: Sendable {
    func execute(groupId: UUID, shortcode: String, mediaId: UUID) async throws -> CustomEmoji
}

public final class AddGroupCustomEmojiUseCase: AddGroupCustomEmojiUseCaseProtocol, Sendable {
    private let repository: CustomEmojiRepositoryProtocol

    public init(repository: CustomEmojiRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID, shortcode: String, mediaId: UUID) async throws -> CustomEmoji {
        try await repository.addEmoji(groupId: groupId, shortcode: shortcode, mediaId: mediaId)
    }
}
