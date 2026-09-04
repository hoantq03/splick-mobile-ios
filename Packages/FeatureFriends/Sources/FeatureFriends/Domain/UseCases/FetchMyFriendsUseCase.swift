import Foundation
import SplickDomain

public protocol FetchMyFriendsUseCaseProtocol: Sendable {
    func execute() async throws -> [UserSummary]
    func executePage(page: Int, size: Int) async throws -> FriendsPageResult
    func loadCached(userId: UUID) async -> [UserSummary]?
    func saveCached(_ friends: [UserSummary], userId: UUID) async
    func invalidateCache(userId: UUID) async
}

public struct FetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [UserSummary] {
        try await repository.fetchMyFriends()
    }

    public func executePage(page: Int, size: Int) async throws -> FriendsPageResult {
        try await repository.fetchMyFriendsPage(page: page, size: size)
    }

    public func loadCached(userId: UUID) async -> [UserSummary]? {
        await repository.loadCachedFriends(userId: userId)
    }

    public func saveCached(_ friends: [UserSummary], userId: UUID) async {
        await repository.saveCachedFriends(friends, userId: userId)
    }

    public func invalidateCache(userId: UUID) async {
        await repository.invalidateCachedFriends(userId: userId)
    }
}
