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
        let dto = GoogleSignInRequestDTO(idToken: idToken, deviceInfo: DeviceInfo.current)
        let response: AuthResponseDTO = try await apiClient.request(AuthEndpoint.googleSignIn(dto))
        try await persistSession(response)
        return AuthMapper.toAuthSession(response)
    }

    public func login(email: String, password: String) async throws -> AuthSession {
        let dto = LoginRequestDTO(
            email: email,
            password: password,
            deviceInfo: DeviceInfo.current
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
        let dto = PhoneOtpVerifyRequestDTO(
            phoneNumber: phoneNumber,
            otpCode: otpCode,
            deviceInfo: DeviceInfo.current
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
        let dto = EmailRegisterRequestDTO(
            email: email,
            username: username,
            password: password,
            otpCode: otpCode,
            displayName: displayName
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
        let dto = PhoneRegisterRequestDTO(
            phoneNumber: phoneNumber,
            username: username,
            password: password,
            otpCode: otpCode,
            displayName: displayName
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

    public func logout() async {
        do {
            try await apiClient.request(AuthEndpoint.logout)
            Log.info("Server session revoked", category: .auth)
        } catch {
            Log.error("Remote logout failed; clearing local session anyway: \(error)", category: .auth)
        }
        await clearLocalCredentials()
    }

    public func getCurrentUser() async throws -> User {
        let dto: UserDTO = try await apiClient.request(AuthEndpoint.me)
        return AuthMapper.toUser(dto)
    }

    // MARK: - Private

    private func clearLocalCredentials() async {
        try? keychainService.delete(for: AppConstants.Keychain.accessTokenKey)
        try? keychainService.delete(for: AppConstants.Keychain.refreshTokenKey)
        try? keychainService.delete(for: AppConstants.Keychain.userIdKey)
        await tokenProvider.clearTokens()
    }

    private func persistSession(_ response: AuthResponseDTO) async throws {
        try keychainService.saveString(response.accessToken, for: AppConstants.Keychain.accessTokenKey)
        try keychainService.saveString(response.refreshToken, for: AppConstants.Keychain.refreshTokenKey)
        try keychainService.saveString(response.user.id.uuidString, for: AppConstants.Keychain.userIdKey)
        await tokenProvider.updateTokens(
            access: response.accessToken,
            refresh: response.refreshToken
        )
    }
}

private enum DeviceInfo {
    static var current: String {
        #if os(iOS)
        return "Splick iOS"
        #else
        return "Splick"
        #endif
    }
}
