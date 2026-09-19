import Foundation
import SplickDomain

public protocol CreatePostUseCaseProtocol: Sendable {
    func execute(_ input: CreatePostInput) async throws -> Post
}

public final class CreatePostUseCase: CreatePostUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(_ input: CreatePostInput) async throws -> Post {
        try await repository.createPost(input)
    }
}
