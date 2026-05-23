import Foundation

public protocol FetchOutgoingFriendRequestsUseCaseProtocol: Sendable {
    func execute(page: Int, size: Int) async throws -> [OutgoingFriendRequest]
}

public struct FetchOutgoingFriendRequestsUseCase: FetchOutgoingFriendRequestsUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(page: Int = 0, size: Int = 50) async throws -> [OutgoingFriendRequest] {
        try await repository.fetchOutgoingFriendRequests(page: page, size: size)
    }
}
