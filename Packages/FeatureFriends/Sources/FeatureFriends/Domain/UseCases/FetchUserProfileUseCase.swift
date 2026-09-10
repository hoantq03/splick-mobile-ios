import Foundation

public protocol FetchUserProfileUseCaseProtocol: Sendable {
    func execute(userId: UUID) async throws -> PublicUserProfile
}

public struct FetchUserProfileUseCase: FetchUserProfileUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(userId: UUID) async throws -> PublicUserProfile {
        try await repository.fetchUserProfile(userId: userId)
    }
}
