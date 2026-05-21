import Foundation
import SplickDomain

public protocol SearchUsersUseCaseProtocol: Sendable {
    func execute(query: String, page: Int, size: Int) async throws -> [UserSummary]
}

public struct SearchUsersUseCase: SearchUsersUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(query: String, page: Int = 0, size: Int = 20) async throws -> [UserSummary] {
        try await repository.searchUsers(query: query, page: page, size: size)
    }
}
