import Foundation

public protocol FetchBlockedUsersUseCaseProtocol: Sendable {
    func execute(page: Int, size: Int) async throws -> [BlockedUser]
    func executeAll() async throws -> [BlockedUser]
}

public struct FetchBlockedUsersUseCase: FetchBlockedUsersUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(page: Int = 0, size: Int = 50) async throws -> [BlockedUser] {
        try await repository.fetchBlockedUsers(page: page, size: size)
    }

    public func executeAll() async throws -> [BlockedUser] {
        try await repository.fetchAllBlockedUsers()
    }
}
