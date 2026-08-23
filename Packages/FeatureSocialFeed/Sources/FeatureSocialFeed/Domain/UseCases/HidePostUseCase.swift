import Foundation
import SplickDomain

public protocol HidePostUseCaseProtocol: Sendable {
    func execute(postId: UUID) async throws
}

public final class HidePostUseCase: HidePostUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(postId: UUID) async throws {
        try await repository.hidePost(id: postId)
    }
}
