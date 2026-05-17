import Foundation
import SplickDomain

public protocol ReactToPostUseCaseProtocol: Sendable {
    func execute(postId: UUID, emoji: String) async throws -> Reaction
}

public final class ReactToPostUseCase: ReactToPostUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(postId: UUID, emoji: String) async throws -> Reaction {
        try await repository.addReaction(postId: postId, emoji: emoji)
    }
}
