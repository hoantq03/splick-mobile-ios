import Foundation

public protocol BlockUserUseCaseProtocol: Sendable {
    func execute(userId: UUID) async throws
}

public struct BlockUserUseCase: BlockUserUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(userId: UUID) async throws {
        try await repository.blockUser(userId: userId)
    }
}
