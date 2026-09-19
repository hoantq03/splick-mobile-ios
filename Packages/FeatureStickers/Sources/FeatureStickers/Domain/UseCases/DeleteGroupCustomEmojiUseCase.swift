import Foundation

public protocol DeleteUserCustomEmojiUseCaseProtocol: Sendable {
    func execute(emojiId: UUID) async throws
}

public final class DeleteUserCustomEmojiUseCase: DeleteUserCustomEmojiUseCaseProtocol, Sendable {
    private let repository: CustomEmojiRepositoryProtocol

    public init(repository: CustomEmojiRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(emojiId: UUID) async throws {
        try await repository.deleteEmoji(emojiId: emojiId)
    }
}
