import Foundation
import SplickDomain

public protocol UpdatePostUseCaseProtocol: Sendable {
    func execute(_ input: UpdatePostInput) async throws -> Post
}

public final class UpdatePostUseCase: UpdatePostUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(_ input: UpdatePostInput) async throws -> Post {
        try await repository.updatePost(input)
    }
}

public protocol FetchPostEditHistoryUseCaseProtocol: Sendable {
    func execute(postId: UUID) async throws -> [PostEditRevision]
}

public final class FetchPostEditHistoryUseCase: FetchPostEditHistoryUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(postId: UUID) async throws -> [PostEditRevision] {
        try await repository.fetchPostEdits(postId: postId)
    }
}
