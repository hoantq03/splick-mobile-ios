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
    private let userDefaultsService: UserDefaultsServiceProtocol

    public init(
        repository: AuthRepositoryProtocol,
        sessionManager: SessionManagerProtocol,
        keychainService: KeychainServiceProtocol,
        tokenProvider: TokenProvider,
        refreshTokenUseCase: RefreshTokenUseCaseProtocol,
        userDefaultsService: UserDefaultsServiceProtocol
    ) {
        self.repository = repository
        self.sessionManager = sessionManager
        self.keychainService = keychainService
        self.tokenProvider = tokenProvider
        self.refreshTokenUseCase = refreshTokenUseCase
        self.userDefaultsService = userDefaultsService
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
            return await activateSession(
                user: user,
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        } catch NetworkError.unauthorized {
            do {
                try await refreshTokenUseCase.refreshSession()
                return await sessionManager.currentSession()
            } catch {
                return await recoverOrSignOut(
                    error: error,
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )
            }
        } catch {
            return await recoverOrSignOut(
                error: error,
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        }
    }

    private func recoverOrSignOut(
        error: Error,
        accessToken: String,
        refreshToken: String
    ) async -> AuthSession? {
        if shouldInvalidateSession(error) {
            await clearStoredSession()
            return nil
        }

        guard let session = await offlineSession(accessToken: accessToken, refreshToken: refreshToken) else {
            Log.error("Offline session restore failed: no cached user", category: .auth)
            return nil
        }

        Log.info("Restored local session while offline", category: .auth)
        await sessionManager.setSession(session)
        return session
    }

    private func activateSession(
        user: User,
        accessToken: String,
        refreshToken: String
    ) async -> AuthSession? {
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
    }

    private func offlineSession(accessToken: String, refreshToken: String) async -> AuthSession? {
        if let cached: User = userDefaultsService.get(for: AppConstants.UserDefaults.cachedCurrentUser),
           cached.status.allowsSignIn {
            return AuthSession(
                user: cached,
                token: AuthToken(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    expiresIn: 0,
                    tokenType: "Bearer"
                )
            )
        }

        guard
            let userIdString = try? keychainService.loadString(for: AppConstants.Keychain.userIdKey),
            let userId = UUID(uuidString: userIdString)
        else {
            return nil
        }

        return AuthSession(
            user: User(
                id: userId,
                email: "",
                username: "",
                displayName: ""
            ),
            token: AuthToken(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresIn: 0,
                tokenType: "Bearer"
            )
        )
    }

    private func shouldInvalidateSession(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            return !networkError.shouldKeepLocalSession
        }
        if let authError = error as? AuthError {
            switch authError {
            case .accountLocked, .accountInactive, .refreshFailed:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func clearStoredSession() async {
        try? keychainService.delete(for: AppConstants.Keychain.accessTokenKey)
        try? keychainService.delete(for: AppConstants.Keychain.refreshTokenKey)
        try? keychainService.delete(for: AppConstants.Keychain.userIdKey)
        userDefaultsService.remove(for: AppConstants.UserDefaults.cachedCurrentUser)
        await tokenProvider.clearTokens()
        await sessionManager.clearSession()
    }
}
