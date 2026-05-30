import Foundation
import Common
import SplickDomain

public protocol ChangePasswordUseCaseProtocol: Sendable {
    func execute(
        currentPassword: String?,
        otpCode: String?,
        newPassword: String
    ) async throws -> AuthSession
}

public final class ChangePasswordUseCase: ChangePasswordUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute(
        currentPassword: String?,
        otpCode: String?,
        newPassword: String
    ) async throws -> AuthSession {
        do {
            let session = try await repository.changePassword(
                currentPassword: currentPassword,
                otpCode: otpCode,
                newPassword: newPassword
            )
            guard session.user.status.allowsSignIn else {
                throw AuthError.accountLocked
            }
            await sessionManager.setSession(session)
            return session
        } catch let error as NetworkError {
            if case .unauthorized = error {
                throw AuthError.invalidCredentials
            }
            throw error
        }
    }
}
