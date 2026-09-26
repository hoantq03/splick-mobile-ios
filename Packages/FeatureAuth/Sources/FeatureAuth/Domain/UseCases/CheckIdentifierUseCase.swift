import Foundation

public protocol CheckIdentifierUseCaseProtocol: Sendable {
    func execute(email: String?, phoneNumber: String?) async throws -> Bool
}

public final class CheckIdentifierUseCase: CheckIdentifierUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(email: String?, phoneNumber: String?) async throws -> Bool {
        try await repository.checkIdentifier(email: email, phoneNumber: phoneNumber)
    }
}
