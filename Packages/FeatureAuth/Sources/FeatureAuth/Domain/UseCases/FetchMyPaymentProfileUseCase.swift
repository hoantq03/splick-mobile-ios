import Foundation
import SplickDomain

public protocol FetchMyPaymentProfileUseCaseProtocol: Sendable {
    func execute() async throws -> PaymentProfile
}

public struct FetchMyPaymentProfileUseCase: FetchMyPaymentProfileUseCaseProtocol {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> PaymentProfile {
        try await repository.fetchMyPaymentProfile()
    }
}
