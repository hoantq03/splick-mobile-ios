import Foundation
import SplickDomain

public protocol AddCommentUseCaseProtocol: Sendable {
    func execute(postId: UUID, body: String, parentCommentId: UUID?) async throws
}

public final class AddCommentUseCase: AddCommentUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(postId: UUID, body: String, parentCommentId: UUID?) async throws {
        try await repository.addComment(postId: postId, body: body, parentCommentId: parentCommentId)
    }
}
