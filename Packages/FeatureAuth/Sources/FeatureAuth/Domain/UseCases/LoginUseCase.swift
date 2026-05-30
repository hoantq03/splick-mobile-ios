import Foundation
import Common
import SplickDomain

public protocol LoginUseCaseProtocol: Sendable {
    func execute(email: String, password: String) async throws -> AuthSession
}

public final class LoginUseCase: LoginUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol

    public init(repository: AuthRepositoryProtocol, sessionManager: SessionManagerProtocol) {
        self.repository = repository
        self.sessionManager = sessionManager
    }

    public func execute(email: String, password: String) async throws -> AuthSession {
        do {
            let session = try await repository.login(email: email, password: password)
            if session.user.status == .inactive {
                throw AuthError.accountInactive
            }
            guard session.user.status.allowsSignIn else {
                throw AuthError.accountLocked
            }
            await sessionManager.setSession(session)
            return session
        } catch let error as AuthError {
            throw error
        } catch let error as NetworkError where error.isConnectivityIssue {
            throw error
        } catch {
            throw AuthError.invalidCredentials
        }
    }
}
