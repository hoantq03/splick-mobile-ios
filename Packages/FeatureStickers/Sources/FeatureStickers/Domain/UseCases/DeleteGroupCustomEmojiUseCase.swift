import Foundation

public protocol DeleteGroupCustomEmojiUseCaseProtocol: Sendable {
    func execute(groupId: UUID, emojiId: UUID) async throws
}

public final class DeleteGroupCustomEmojiUseCase: DeleteGroupCustomEmojiUseCaseProtocol, Sendable {
    private let repository: CustomEmojiRepositoryProtocol

    public init(repository: CustomEmojiRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID, emojiId: UUID) async throws {
        try await repository.deleteEmoji(groupId: groupId, emojiId: emojiId)
    }
}
