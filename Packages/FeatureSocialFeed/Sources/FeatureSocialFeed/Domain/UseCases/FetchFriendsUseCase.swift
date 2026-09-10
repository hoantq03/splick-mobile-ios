import Foundation
import SplickDomain

public protocol FetchFriendsUseCaseProtocol: Sendable {
    func execute(query: String, page: Int, limit: Int) async throws -> [UserSummary]
}

public final class FetchFriendsUseCase: FetchFriendsUseCaseProtocol, Sendable {
    private let repository: FriendsRepositoryProtocol

    public init(repository: FriendsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(query: String, page: Int, limit: Int) async throws -> [UserSummary] {
        try await repository.fetchFriends(query: query, page: page, limit: limit)
    }
}
