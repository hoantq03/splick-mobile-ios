import Foundation

public protocol ForgotPasswordUseCaseProtocol: Sendable {
    func execute(email: String) async throws
}

public final class ForgotPasswordUseCase: ForgotPasswordUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(email: String) async throws {
        try await repository.forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
