import Foundation

public protocol FetchIncomingFriendRequestsUseCaseProtocol: Sendable {
    func execute(page: Int, size: Int) async throws -> [IncomingFriendRequest]
    func executeAll() async throws -> [IncomingFriendRequest]
}

public struct FetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(page: Int = 0, size: Int = 50) async throws -> [IncomingFriendRequest] {
        try await repository.fetchIncomingFriendRequests(page: page, size: size)
    }

    public func executeAll() async throws -> [IncomingFriendRequest] {
        try await repository.fetchAllIncomingFriendRequests()
    }
}
