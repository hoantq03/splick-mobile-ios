import Foundation
import SplickDomain

public protocol DeletePostUseCaseProtocol: Sendable {
    func execute(postId: UUID) async throws
}

public final class DeletePostUseCase: DeletePostUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(postId: UUID) async throws {
        try await repository.deletePost(id: postId)
    }
}
