import Foundation
import SplickDomain

public protocol AddFriendUseCaseProtocol: Sendable {
    func execute(username: String, message: String?) async throws -> UserSummary
    func executeFromQRCode(_ payload: String, message: String?) async throws -> UserSummary
}

public struct AddFriendUseCase: AddFriendUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(username: String, message: String? = nil) async throws -> UserSummary {
        try await repository.addFriend(username: username, message: message)
    }

    public func executeFromQRCode(_ payload: String, message: String? = nil) async throws -> UserSummary {
        try await repository.addFriendFromQRCode(payload)
    }
}
