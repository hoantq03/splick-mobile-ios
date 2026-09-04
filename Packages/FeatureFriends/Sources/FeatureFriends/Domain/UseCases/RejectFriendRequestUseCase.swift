import Foundation

public protocol RejectFriendRequestUseCaseProtocol: Sendable {
    func execute(requestId: UUID) async throws
}

public struct RejectFriendRequestUseCase: RejectFriendRequestUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(requestId: UUID) async throws {
        try await repository.rejectFriendRequest(requestId: requestId)
    }
}
