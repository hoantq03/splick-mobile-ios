import Foundation
import Storage
import Networking
import Common
import SplickDomain

public enum SessionConfirmation: Sendable {
    /// Server returned a fresh profile.
    case updated(AuthSession)
    /// Network/transient failure — keep the local session.
    case unchanged
    /// Refresh token is invalid or the account cannot sign in.
    case signedOut
}

public protocol RestoreSessionUseCaseProtocol: Sendable {
    /// True when Keychain still holds an access token from a previous login.
    func hasStoredCredentials() -> Bool
    /// Restores tokens + cached profile without hitting the network.
    func restoreLocal() async -> AuthSession?
    /// Revalidates with `/v1/auth/me`. Never clears tokens on connectivity errors.
    func confirmRemote() async -> SessionConfirmation
    /// Local restore, then optional remote confirm (blocking). Prefer `restoreLocal` at launch.
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

    public func hasStoredCredentials() -> Bool {
        storedTokens() != nil
    }

    public func restoreLocal() async -> AuthSession? {
        guard let tokens = storedTokens() else { return nil }
        await tokenProvider.updateTokens(access: tokens.access, refresh: tokens.refresh)
        guard let session = localSession(accessToken: tokens.access, refreshToken: tokens.refresh) else {
            return nil
        }
        persistUserIdIfNeeded(session.user.id)
        await sessionManager.setSession(session)
        Log.info("Restored local session without waiting for network", category: .auth)
        return session
    }

    public func confirmRemote() async -> SessionConfirmation {
        guard storedTokens() != nil else { return .signedOut }

        do {
            let user = try await repository.getCurrentUser()
            let access = await tokenProvider.accessToken() ?? storedTokens()?.access
            let refresh = await tokenProvider.refreshToken() ?? storedTokens()?.refresh
            guard let access, let refresh, !access.isEmpty, !refresh.isEmpty else {
                return .signedOut
            }
            guard let session = await activateSession(
                user: user,
                accessToken: access,
                refreshToken: refresh
            ) else {
                return .signedOut
            }
            return .updated(session)
        } catch NetworkError.unauthorized {
            do {
                try await refreshTokenUseCase.refreshSession()
                if let session = await sessionManager.currentSession() {
                    return .updated(session)
                }
                return .unchanged
            } catch {
                return await confirmationAfterRemoteFailure(error)
            }
        } catch {
            return await confirmationAfterRemoteFailure(error)
        }
    }

    public func execute() async -> AuthSession? {
        guard let local = await restoreLocal() else { return nil }
        switch await confirmRemote() {
        case .updated(let session):
            return session
        case .unchanged:
            return local
        case .signedOut:
            return nil
        }
    }

    // MARK: - Private

    private func confirmationAfterRemoteFailure(_ error: Error) async -> SessionConfirmation {
        if shouldInvalidateSession(error) {
            await clearStoredSession()
            Log.info("Remote session confirmation signed the user out", category: .auth)
            return .signedOut
        }
        Log.info("Keeping local session after remote confirmation failed", category: .auth)
        return .unchanged
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
        persistUserIdIfNeeded(user.id)
        await sessionManager.setSession(session)
        return session
    }

    private func localSession(accessToken: String, refreshToken: String) -> AuthSession? {
        if let cached: User = userDefaultsService.get(for: AppConstants.UserDefaults.cachedCurrentUser),
           cached.status.allowsSignIn {
            return makeSession(user: cached, accessToken: accessToken, refreshToken: refreshToken)
        }

        let userId = storedUserId() ?? userIdFromAccessToken(accessToken)
        guard let userId else { return nil }

        return makeSession(
            user: User(
                id: userId,
                email: "",
                username: "",
                displayName: ""
            ),
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }

    private func makeSession(user: User, accessToken: String, refreshToken: String) -> AuthSession {
        AuthSession(
            user: user,
            token: AuthToken(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresIn: 0,
                tokenType: "Bearer"
            )
        )
    }

    private func storedTokens() -> (access: String, refresh: String)? {
        guard
            let accessToken = try? keychainService.loadString(for: AppConstants.Keychain.accessTokenKey),
            let refreshToken = try? keychainService.loadString(for: AppConstants.Keychain.refreshTokenKey),
            !accessToken.isEmpty,
            !refreshToken.isEmpty
        else {
            return nil
        }
        return (accessToken, refreshToken)
    }

    private func storedUserId() -> UUID? {
        guard
            let userIdString = try? keychainService.loadString(for: AppConstants.Keychain.userIdKey),
            let userId = UUID(uuidString: userIdString)
        else {
            return nil
        }
        return userId
    }

    private func persistUserIdIfNeeded(_ userId: UUID) {
        let existing = try? keychainService.loadString(for: AppConstants.Keychain.userIdKey)
        guard existing != userId.uuidString else { return }
        try? keychainService.saveString(userId.uuidString, for: AppConstants.Keychain.userIdKey)
    }

    private func userIdFromAccessToken(_ token: String) -> UUID? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 {
            payload.append("=")
        }

        guard
            let data = Data(base64Encoded: payload),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let sub = json["sub"] as? String, let userId = UUID(uuidString: sub) {
            return userId
        }
        return nil
    }

    private func shouldInvalidateSession(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            return !networkError.shouldKeepLocalSession
        }
        if let authError = error as? AuthError {
            switch authError {
            case .accountLocked, .accountInactive:
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
