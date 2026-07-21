import Foundation
import FeatureFriends
import SplickDomain

public final class FetchUserPostsUseCase: FetchUserPostsUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol
    private let pageSize: Int

    public init(repository: FeedRepositoryProtocol, pageSize: Int = 20) {
        self.repository = repository
        self.pageSize = pageSize
    }

    public func execute(authorId: UUID, page: Int) async throws -> [Post] {
        try await repository.fetchFeed(
            page: page,
            limit: pageSize,
            authorId: authorId
        )
    }
}
