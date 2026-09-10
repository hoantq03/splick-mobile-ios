import Foundation

public protocol GenerateGroupInviteCodeUseCaseProtocol: Sendable {
    func execute(groupId: UUID) async throws -> GroupInviteCode
}

public struct GenerateGroupInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(groupId: UUID) async throws -> GroupInviteCode {
        try await repository.generateInviteCode(groupId: groupId)
    }
}
