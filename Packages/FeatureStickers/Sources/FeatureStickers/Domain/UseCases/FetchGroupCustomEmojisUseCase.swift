import Foundation
import SplickDomain

public protocol FetchGroupCustomEmojisUseCaseProtocol: Sendable {
    func execute(groupId: UUID) async throws -> [CustomEmoji]
}

public final class FetchGroupCustomEmojisUseCase: FetchGroupCustomEmojisUseCaseProtocol, Sendable {
    private let repository: CustomEmojiRepositoryProtocol

    public init(repository: CustomEmojiRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID) async throws -> [CustomEmoji] {
        try await repository.fetchEmojis(groupId: groupId)
    }
}
