import Foundation
import SplickDomain

public protocol JoinGroupUseCaseProtocol: Sendable {
    func execute(inviteCode: String) async throws -> Group
    func executeFromQRCode(_ payload: String) async throws -> Group
}

public struct JoinGroupUseCase: JoinGroupUseCaseProtocol {
    private let repository: GroupsRepositoryProtocol

    public init(repository: GroupsRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(inviteCode: String) async throws -> Group {
        try await repository.joinGroup(inviteCode: inviteCode)
    }

    public func executeFromQRCode(_ payload: String) async throws -> Group {
        try await repository.joinGroupFromQRCode(payload)
    }
}
