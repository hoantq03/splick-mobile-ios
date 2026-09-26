import Foundation

public protocol AcceptFriendRequestUseCaseProtocol: Sendable {
    func execute(requestId: UUID) async throws
}

public struct AcceptFriendRequestUseCase: AcceptFriendRequestUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(requestId: UUID) async throws {
        try await repository.acceptFriendRequest(requestId: requestId)
    }
}
