import Foundation
import SplickDomain

public protocol FetchPostUseCaseProtocol: Sendable {
    func execute(postId: UUID) async throws -> Post
}

public final class FetchPostUseCase: FetchPostUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(postId: UUID) async throws -> Post {
        try await repository.fetchPost(id: postId)
    }
}
