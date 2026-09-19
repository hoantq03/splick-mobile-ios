import Foundation

public protocol FetchGroupInviteCodeUseCaseProtocol: Sendable {
    func execute(groupId: UUID) async throws -> GroupInviteCode?
}

public struct FetchGroupInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID) async throws -> GroupInviteCode? {
        try await repository.fetchActiveInviteCode(groupId: groupId)
    }
}
