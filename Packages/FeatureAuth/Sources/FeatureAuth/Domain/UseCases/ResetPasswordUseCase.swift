import Foundation
import Common
import SplickDomain

public protocol ResetPasswordUseCaseProtocol: Sendable {
    func execute(email: String, otpCode: String, newPassword: String) async throws -> AuthSession
}

public final class ResetPasswordUseCase: ResetPasswordUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute(email: String, otpCode: String, newPassword: String) async throws -> AuthSession {
        let session = try await repository.resetPassword(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            otpCode: otpCode,
            newPassword: newPassword
        )
        guard session.user.status.allowsSignIn else {
            throw AuthError.accountLocked
        }
        await sessionManager.setSession(session)
        return session
    }
}
