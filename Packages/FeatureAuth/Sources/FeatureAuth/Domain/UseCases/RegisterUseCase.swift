import Foundation
import Common
import SplickDomain

public protocol RegisterUseCaseProtocol: Sendable {
    func execute(
        channel: AuthRegistrationChannel,
        identifier: String,
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
        channel: AuthRegistrationChannel,
        identifier: String,
        username: String,
        password: String,
        otpCode: String,
        displayName: String?
    ) async throws -> AuthSession {
        let session: AuthSession
        switch channel {
        case .email:
            session = try await repository.registerWithEmail(
                email: identifier,
                username: username,
                password: password,
                otpCode: otpCode,
                displayName: displayName
            )
        case .phone:
            session = try await repository.registerWithPhone(
                phoneNumber: identifier,
                username: username,
                password: password,
                otpCode: otpCode,
                displayName: displayName
            )
        }
        guard session.user.status.allowsSignIn else {
            throw AuthError.accountLocked
        }
        await sessionManager.setSession(session)
        return session
    }
}
