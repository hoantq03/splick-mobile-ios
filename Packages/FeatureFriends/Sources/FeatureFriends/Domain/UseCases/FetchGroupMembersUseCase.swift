import Foundation
import SplickDomain

public protocol FetchGroupMembersUseCaseProtocol: Sendable {
    func execute(groupId: UUID, status: String?) async throws -> [GroupMemberItem]
}

public struct FetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID, status: String? = "ACTIVE") async throws -> [GroupMemberItem] {
        try await repository.fetchGroupMembers(groupId: groupId, status: status)
    }
}
