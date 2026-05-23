import Foundation
import SplickDomain

public protocol SetFriendNicknameUseCaseProtocol: Sendable {
    func execute(friendUserId: UUID, nickname: String?) async throws -> UserSummary
}

public struct SetFriendNicknameUseCase: SetFriendNicknameUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(friendUserId: UUID, nickname: String?) async throws -> UserSummary {
        try await repository.setFriendNickname(friendUserId: friendUserId, nickname: nickname)
    }
}
