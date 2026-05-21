import Foundation

public protocol InviteFriendsToGroupUseCaseProtocol: Sendable {
    func execute(groupId: UUID, userIds: [UUID]) async throws -> InviteFriendsToGroupResult
}

public struct InviteFriendsToGroupUseCase: InviteFriendsToGroupUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID, userIds: [UUID]) async throws -> InviteFriendsToGroupResult {
        try await repository.inviteFriends(groupId: groupId, userIds: userIds)
    }
}
