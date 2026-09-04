import Foundation

public protocol RemoveFriendUseCaseProtocol: Sendable {
    func execute(friendUserId: UUID) async throws
}

public struct RemoveFriendUseCase: RemoveFriendUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(friendUserId: UUID) async throws {
        try await repository.removeFriend(friendUserId: friendUserId)
    }
}
