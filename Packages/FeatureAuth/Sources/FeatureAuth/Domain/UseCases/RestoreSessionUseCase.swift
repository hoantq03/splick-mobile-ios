import Foundation
import Storage
import Networking
import Common
import SplickDomain

public protocol RestoreSessionUseCaseProtocol: Sendable {
    /// Returns a session when Keychain tokens are valid; otherwise `nil`.
    func execute() async -> AuthSession?
}

public final class RestoreSessionUseCase: RestoreSessionUseCaseProtocol, Sendable {
    private let repository: AuthRepositoryProtocol
    private let sessionManager: SessionManagerProtocol
    private let keychainService: KeychainServiceProtocol
    private let tokenProvider: TokenProvider
    private let refreshTokenUseCase: RefreshTokenUseCaseProtocol

    public init(
        repository: AuthRepositoryProtocol,
        sessionManager: SessionManagerProtocol,
        keychainService: KeychainServiceProtocol,
        tokenProvider: TokenProvider,
        refreshTokenUseCase: RefreshTokenUseCaseProtocol
    ) {
        self.repository = repository
        self.sessionManager = sessionManager
        self.keychainService = keychainService
        self.tokenProvider = tokenProvider
        self.refreshTokenUseCase = refreshTokenUseCase
    }

    public func execute() async -> AuthSession? {
        guard
            let accessToken = try? keychainService.loadString(for: AppConstants.Keychain.accessTokenKey),
            let refreshToken = try? keychainService.loadString(for: AppConstants.Keychain.refreshTokenKey),
            !accessToken.isEmpty,
            !refreshToken.isEmpty
        else {
            return nil
        }

        await tokenProvider.updateTokens(access: accessToken, refresh: refreshToken)

        do {
            let user = try await repository.getCurrentUser()
            guard user.status.allowsSignIn else {
                await clearStoredSession()
                return nil
            }
            let session = AuthSession(
                user: user,
                token: AuthToken(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    expiresIn: 0,
                    tokenType: "Bearer"
                )
            )
            await sessionManager.setSession(session)
            return session
        } catch NetworkError.unauthorized {
            do {
                try await refreshTokenUseCase.refreshSession()
                return await sessionManager.currentSession()
            } catch {
                await clearStoredSession()
                return nil
            }
        } catch {
            await clearStoredSession()
            return nil
        }
    }

    private func clearStoredSession() async {
        try? keychainService.delete(for: AppConstants.Keychain.accessTokenKey)
        try? keychainService.delete(for: AppConstants.Keychain.refreshTokenKey)
        try? keychainService.delete(for: AppConstants.Keychain.userIdKey)
        await tokenProvider.clearTokens()
        await sessionManager.clearSession()
    }
}
