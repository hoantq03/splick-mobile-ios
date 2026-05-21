import Foundation
import SplickDomain

public protocol FetchGroupMembersUseCaseProtocol: Sendable {
    func execute(groupId: UUID, status: String?) async throws -> [UserSummary]
}

public struct FetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID, status: String? = "ACTIVE") async throws -> [UserSummary] {
        try await repository.fetchGroupMembers(groupId: groupId, status: status)
    }
}
