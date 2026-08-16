import Foundation
import SplickDomain

public protocol ListPostReactionsUseCaseProtocol: Sendable {
    func execute(postId: UUID) async throws -> [UserReactionSummary]
}

public final class ListPostReactionsUseCase: ListPostReactionsUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(postId: UUID) async throws -> [UserReactionSummary] {
        try await repository.fetchPostReactions(postId: postId)
    }
}
