import Foundation

public protocol UnblockUserUseCaseProtocol: Sendable {
    func execute(userId: UUID) async throws
}

public struct UnblockUserUseCase: UnblockUserUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(userId: UUID) async throws {
        try await repository.unblockUser(userId: userId)
    }
}
