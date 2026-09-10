import Foundation

public protocol CancelFriendRequestUseCaseProtocol: Sendable {
    func execute(requestId: UUID) async throws
}

public struct CancelFriendRequestUseCase: CancelFriendRequestUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(requestId: UUID) async throws {
        try await repository.cancelFriendRequest(requestId: requestId)
    }
}
