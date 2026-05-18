import Foundation
import SplickDomain

public protocol AddFriendUseCaseProtocol: Sendable {
    func execute(username: String) async throws -> UserSummary
    func executeFromQRCode(_ payload: String) async throws -> UserSummary
}

public struct AddFriendUseCase: AddFriendUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(username: String) async throws -> UserSummary {
        try await repository.addFriend(username: username)
    }

    public func executeFromQRCode(_ payload: String) async throws -> UserSummary {
        try await repository.addFriendFromQRCode(payload)
    }
}
