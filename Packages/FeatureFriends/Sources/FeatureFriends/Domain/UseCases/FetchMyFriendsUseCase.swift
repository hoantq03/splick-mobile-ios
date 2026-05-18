import Foundation
import SplickDomain

public protocol FetchMyFriendsUseCaseProtocol: Sendable {
    func execute() async throws -> [UserSummary]
}

public struct FetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [UserSummary] {
        try await repository.fetchMyFriends()
    }
}
