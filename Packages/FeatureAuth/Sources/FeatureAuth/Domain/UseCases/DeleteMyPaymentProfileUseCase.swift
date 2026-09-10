import Foundation

public protocol DeleteMyPaymentProfileUseCaseProtocol: Sendable {
    func execute() async throws
}

public struct DeleteMyPaymentProfileUseCase: DeleteMyPaymentProfileUseCaseProtocol {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws {
        try await repository.deleteMyPaymentProfile()
    }
}
