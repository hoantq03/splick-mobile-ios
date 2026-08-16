import Foundation
import SplickDomain

public protocol FetchPostReactionsUseCaseProtocol: Sendable {
    func execute(postId: UUID) async throws -> PostReactionList
}

public final class FetchPostReactionsUseCase: FetchPostReactionsUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(postId: UUID) async throws -> PostReactionList {
        try await repository.fetchPostReactions(postId: postId)
    }
}
