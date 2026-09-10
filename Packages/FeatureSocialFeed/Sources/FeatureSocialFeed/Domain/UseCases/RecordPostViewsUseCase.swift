import Foundation
import SplickDomain

public protocol RecordPostViewsUseCaseProtocol: Sendable {
    func execute(postIds: [UUID]) async throws -> [Post]
}

public final class RecordPostViewsUseCase: RecordPostViewsUseCaseProtocol, Sendable {
    private let repository: FeedRepositoryProtocol

    public init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(postIds: [UUID]) async throws -> [Post] {
        try await repository.recordPostViews(postIds: postIds)
    }
}
