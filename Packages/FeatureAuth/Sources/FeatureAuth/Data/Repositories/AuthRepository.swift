import Foundation
import Networking
import Storage
import Common
import SplickDomain

public final class AuthRepository: AuthRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol
    private let keychainService: KeychainServiceProtocol
    private let tokenProvider: TokenProvider

    public init(
        apiClient: APIClientProtocol,
        keychainService: KeychainServiceProtocol,
        tokenProvider: TokenProvider
    ) {
        self.apiClient = apiClient
        self.keychainService = keychainService
        self.tokenProvider = tokenProvider
    }

    public func signInWithGoogle(idToken: String) async throws -> AuthSession {
        let session = SessionMetadata.current
        let dto = GoogleSignInRequestDTO(
            idToken: idToken,
            deviceInfo: session.deviceInfo,
            deviceName: session.deviceName,
            loginLocation: session.loginLocation
        )
        let response: AuthResponseDTO = try await apiClient.request(AuthEndpoint.googleSignIn(dto))
        try await persistSession(response)
        return AuthMapper.toAuthSession(response)
    }

    public func login(email: String, password: String) async throws -> AuthSession {
        let session = SessionMetadata.current
        let dto = LoginRequestDTO(
            email: email,
            password: password,
            deviceInfo: session.deviceInfo,
            deviceName: session.deviceName,
            loginLocation: session.loginLocation
        )
        let response: AuthResponseDTO = try await apiClient.request(AuthEndpoint.login(dto))
        try await persistSession(response)
        return AuthMapper.toAuthSession(response)
    }

    public func requestEmailOtp(email: String) async throws {
        let dto = EmailOtpRequestDTO(email: email)
        try await apiClient.request(AuthEndpoint.requestEmailOtp(dto))
    }

    public func requestPhoneOtp(phoneNumber: String) async throws {
        let dto = PhoneOtpRequestDTO(phoneNumber: phoneNumber)
        try await apiClient.request(AuthEndpoint.requestPhoneOtp(dto))
    }

    public func verifyPhoneOtp(phoneNumber: String, otpCode: String) async throws -> AuthSession {
        let session = SessionMetadata.current
        let dto = PhoneOtpVerifyRequestDTO(
            phoneNumber: phoneNumber,
            otpCode: otpCode,
            deviceInfo: session.deviceInfo,
            deviceName: session.deviceName,
            loginLocation: session.loginLocation
        )
        let response: AuthResponseDTO = try await apiClient.request(AuthEndpoint.verifyPhoneOtp(dto))
        try await persistSession(response)
        return AuthMapper.toAuthSession(response)
    }

    public func registerWithEmail(
        email: String,
        username: String,
        password: String,
        otpCode: String,
        displayName: String?
    ) async throws -> AuthSession {
        let session = SessionMetadata.current
        let dto = EmailRegisterRequestDTO(
            email: email,
            username: username,
            password: password,
            otpCode: otpCode,
            displayName: displayName,
            deviceInfo: session.deviceInfo,
            deviceName: session.deviceName,
            loginLocation: session.loginLocation
        )
        let response: AuthResponseDTO = try await apiClient.request(AuthEndpoint.registerEmail(dto))
        try await persistSession(response)
        return AuthMapper.toAuthSession(response)
    }

    public func registerWithPhone(
        phoneNumber: String,
        username: String,
        password: String,
        otpCode: String,
        displayName: String?
    ) async throws -> AuthSession {
        let session = SessionMetadata.current
        let dto = PhoneRegisterRequestDTO(
            phoneNumber: phoneNumber,
            username: username,
            password: password,
            otpCode: otpCode,
            displayName: displayName,
            deviceInfo: session.deviceInfo,
            deviceName: session.deviceName,
            loginLocation: session.loginLocation
        )
        let response: AuthResponseDTO = try await apiClient.request(AuthEndpoint.registerPhone(dto))
        try await persistSession(response)
        return AuthMapper.toAuthSession(response)
    }

    public func refreshToken(_ refreshToken: String) async throws -> AuthSession {
        let dto = RefreshTokenRequestDTO(refreshToken: refreshToken)
        let response: AuthResponseDTO = try await apiClient.request(AuthEndpoint.refreshToken(dto))
        try await persistSession(response)
        return AuthMapper.toAuthSession(response)
    }

    public func forgotPassword(email: String) async throws {
        let dto = ForgotPasswordRequestDTO(email: email)
        try await apiClient.request(AuthEndpoint.forgotPassword(dto))
    }

    public func resetPassword(
        email: String,
        otpCode: String,
        newPassword: String
    ) async throws -> AuthSession {
        let session = SessionMetadata.current
        let dto = ResetPasswordRequestDTO(
            email: email,
            otpCode: otpCode,
            newPassword: newPassword,
            deviceInfo: session.deviceInfo,
            deviceName: session.deviceName,
            loginLocation: session.loginLocation
        )
        let response: AuthResponseDTO = try await apiClient.request(AuthEndpoint.resetPassword(dto))
        try await persistSession(response)
        return AuthMapper.toAuthSession(response)
    }

    public func changePassword(
        currentPassword: String?,
        otpCode: String?,
        newPassword: String
    ) async throws -> AuthSession {
        let session = SessionMetadata.current
        let dto = ChangePasswordRequestDTO(
            currentPassword: currentPassword,
            otpCode: otpCode,
            newPassword: newPassword,
            deviceInfo: session.deviceInfo,
            deviceName: session.deviceName,
            loginLocation: session.loginLocation
        )
        let response: AuthResponseDTO = try await apiClient.request(AuthEndpoint.changePassword(dto))
        try await persistSession(response)
        return AuthMapper.toAuthSession(response)
    }

    public func logout() async {
        do {
            if let refreshToken = try? keychainService.loadString(for: AppConstants.Keychain.refreshTokenKey) {
                let dto = LogoutRequestDTO(refreshToken: refreshToken)
                try await apiClient.request(AuthEndpoint.logout(dto))
                Log.info("Server session revoked", category: .auth)
            }
        } catch {
            Log.error("Remote logout failed; clearing local session anyway: \(error)", category: .auth)
        }
        await clearLocalCredentials()
    }

    public func getCurrentUser() async throws -> User {
        let dto: UserDTO = try await apiClient.request(AuthEndpoint.me)
        return AuthMapper.toUser(dto)
    }

    public func updateProfile(
        displayName: String?,
        avatarUrl: String?,
        preferredLocale: String? = nil
    ) async throws -> User {
        let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = (trimmedName?.isEmpty == false) ? trimmedName : nil
        let trimmedAvatar = avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAvatar = (trimmedAvatar?.isEmpty == false) ? trimmedAvatar : nil
        let resolvedLocale = preferredLocale?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLocale = (resolvedLocale?.isEmpty == false) ? resolvedLocale : nil

        if resolvedName == nil && resolvedAvatar == nil && normalizedLocale == nil {
            throw AppError.validation("Enter a display name or avatar URL to update.")
        }

        let dto: UserDTO = try await apiClient.request(
            AuthEndpoint.patchMe(UpdateUserProfileRequestDTO(
                displayName: resolvedName,
                avatarUrl: resolvedAvatar,
                preferredLocale: normalizedLocale
            ))
        )
        return AuthMapper.toUser(dto)
    }

    public func listSessions() async throws -> [UserSession] {
        let refreshToken = try? keychainService.loadString(for: AppConstants.Keychain.refreshTokenKey)
        let dtos: [SessionDTO] = try await apiClient.request(AuthEndpoint.listSessions(refreshToken: refreshToken))
        return dtos.map(AuthMapper.toUserSession)
    }

    public func revokeSession(id: UUID) async throws {
        try await apiClient.request(AuthEndpoint.revokeSession(id))
    }

    public func revokeAllSessions() async throws {
        try await apiClient.request(AuthEndpoint.revokeAllSessions)
    }

    public func deactivateAccount(currentPassword: String?, otpCode: String?) async throws {
        let dto = AccountActionRequestDTO(currentPassword: currentPassword, otpCode: otpCode)
        try await apiClient.request(AuthEndpoint.deactivateAccount(dto))
    }

    public func deleteAccount(currentPassword: String?, otpCode: String?) async throws {
        let dto = AccountActionRequestDTO(currentPassword: currentPassword, otpCode: otpCode)
        try await apiClient.request(AuthEndpoint.deleteAccount(dto))
    }

    public func getConnectedAccounts() async throws -> ConnectedAccounts {
        let dto: ConnectedAccountsDTO = try await apiClient.request(AuthEndpoint.connectedAccounts)
        return AuthMapper.toConnectedAccounts(dto)
    }

    public func linkGoogleAccount(idToken: String) async throws {
        let dto = LinkGoogleRequestDTO(idToken: idToken)
        try await apiClient.request(AuthEndpoint.linkGoogle(dto))
    }

    public func unlinkGoogleAccount(currentPassword: String?, otpCode: String?) async throws {
        let dto = AccountActionRequestDTO(currentPassword: currentPassword, otpCode: otpCode)
        try await apiClient.request(AuthEndpoint.unlinkGoogle(dto))
    }

    public func requestLinkPhoneOtp(phoneNumber: String) async throws {
        let dto = PhoneOtpRequestDTO(phoneNumber: phoneNumber)
        try await apiClient.request(AuthEndpoint.requestLinkPhoneOtp(dto))
    }

    public func linkPhoneAccount(phoneNumber: String, otpCode: String) async throws {
        let dto = LinkPhoneAccountRequestDTO(phoneNumber: phoneNumber, otpCode: otpCode)
        try await apiClient.request(AuthEndpoint.linkPhone(dto))
    }

    public func requestLinkEmailOtp(email: String?) async throws {
        let dto = EmailOtpRequestDTO(email: email ?? "")
        try await apiClient.request(AuthEndpoint.requestLinkEmailOtp(dto))
    }

    public func linkEmailAccount(email: String?, otpCode: String, password: String) async throws {
        let dto = LinkEmailAccountRequestDTO(email: email, otpCode: otpCode, password: password)
        try await apiClient.request(AuthEndpoint.linkEmail(dto))
    }

    // MARK: - Private

    private func clearLocalCredentials() async {
        try? keychainService.delete(for: AppConstants.Keychain.accessTokenKey)
        try? keychainService.delete(for: AppConstants.Keychain.refreshTokenKey)
        try? keychainService.delete(for: AppConstants.Keychain.userIdKey)
        try? keychainService.delete(for: AppConstants.Keychain.sessionIdKey)
        await tokenProvider.clearTokens()
    }

    private func persistSession(_ response: AuthResponseDTO) async throws {
        try keychainService.saveString(response.accessToken, for: AppConstants.Keychain.accessTokenKey)
        try keychainService.saveString(response.refreshToken, for: AppConstants.Keychain.refreshTokenKey)
        try keychainService.saveString(response.user.id.uuidString, for: AppConstants.Keychain.userIdKey)
        if let sessionId = response.sessionId {
            try keychainService.saveString(sessionId.uuidString, for: AppConstants.Keychain.sessionIdKey)
        }
        await tokenProvider.updateTokens(
            access: response.accessToken,
            refresh: response.refreshToken
        )
    }
}
