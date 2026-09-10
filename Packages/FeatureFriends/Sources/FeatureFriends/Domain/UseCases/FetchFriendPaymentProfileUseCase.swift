import Foundation
import SplickDomain

public protocol FetchFriendPaymentProfileUseCaseProtocol: Sendable {
    func execute(userId: UUID) async throws -> PaymentProfile
}

public struct FetchFriendPaymentProfileUseCase: FetchFriendPaymentProfileUseCaseProtocol {
    private let repository: FriendsManagementRepositoryProtocol

    public init(repository: FriendsManagementRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(userId: UUID) async throws -> PaymentProfile {
        try await repository.fetchFriendPaymentProfile(userId: userId)
    }
}
