import Foundation
import Common
import SplickDomain

public protocol RegisterUseCaseProtocol: Sendable {
    func execute(
        email: String,
        username: String,
        password: String,
        otpCode: String,
        displayName: String?
    ) async throws -> AuthSession
}

public final class RegisterUseCase: RegisterUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute(
        email: String,
        username: String,
        password: String,
        otpCode: String,
        displayName: String?
    ) async throws -> AuthSession {
        let session = try await repository.register(
            email: email,
            username: username,
            password: password,
            otpCode: otpCode,
            displayName: displayName
        )
        guard session.user.status.allowsSignIn else {
            throw AuthError.accountLocked
        }
        await sessionManager.setSession(session)
        return session
    }
}
