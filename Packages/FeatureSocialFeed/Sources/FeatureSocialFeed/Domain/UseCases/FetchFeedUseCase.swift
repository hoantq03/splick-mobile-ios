import Foundation
import SplickDomain

public protocol FetchFeedUseCaseProtocol: Sendable {
    func execute(page: Int) async throws -> [Post]
}

public final class FetchFeedUseCase: FetchFeedUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol
    private let pageSize: Int

    public init(repository: FeedRepositoryProtocol, pageSize: Int = 20) {
        self.repository = repository
        self.pageSize = pageSize
    }

    public func execute(page: Int) async throws -> [Post] {
        try await repository.fetchFeed(page: page, limit: pageSize)
    }
}
