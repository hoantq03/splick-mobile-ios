import Foundation
import Networking
import SplickDomain
import Common

public protocol RefreshTokenUseCaseProtocol: Sendable, TokenRefreshHandling {
    func refreshSession() async throws
}

public final class RefreshTokenUseCase: RefreshTokenUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol
    private let tokenProvider: TokenProvider

    public init(
        repository: AuthRepositoryProtocol,
        sessionManager: SessionManagerProtocol,
        tokenProvider: TokenProvider
    ) {
        self.repository = repository
        self.sessionManager = sessionManager
        self.tokenProvider = tokenProvider
    }

    public func refreshSession() async throws {
        guard let refreshToken = await tokenProvider.refreshToken() else {
            throw AuthError.refreshFailed
        }
        let session = try await repository.refreshToken(refreshToken)
        guard session.user.status.allowsSignIn else {
            await sessionManager.clearSession()
            throw AuthError.accountLocked
        }
        await sessionManager.setSession(session)
    }
}
