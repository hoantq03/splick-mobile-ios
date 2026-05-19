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

    public func register(
        email: String,
        username: String,
        password: String,
        otpCode: String,
        displayName: String?
    ) async throws -> AuthSession {
        let trimmedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let dto = RegisterRequestDTO(
            email: email,
            username: username,
            password: password,
            otpCode: otpCode,
            displayName: trimmedDisplayName?.isEmpty == false ? trimmedDisplayName : nil
        )
        let response: AuthResponseDTO = try await apiClient.request(AuthEndpoint.register(dto))
        try await persistSession(response)
        return AuthMapper.toAuthSession(response)
    }

    public func refreshToken(_ refreshToken: String) async throws -> AuthSession {
        let dto = RefreshTokenRequestDTO(refreshToken: refreshToken)
        let response: AuthResponseDTO = try await apiClient.request(AuthEndpoint.refreshToken(dto))
        try await persistSession(response)
        return AuthMapper.toAuthSession(response)
    }

    public func logout() async throws {
        try? await apiClient.request(AuthEndpoint.logout)
        try? keychainService.delete(for: AppConstants.Keychain.accessTokenKey)
        try? keychainService.delete(for: AppConstants.Keychain.refreshTokenKey)
        try? keychainService.delete(for: AppConstants.Keychain.userIdKey)
        await tokenProvider.clearTokens()
    }

    public func getCurrentUser() async throws -> User {
        let dto: UserDTO = try await apiClient.request(AuthEndpoint.me)
        return AuthMapper.toUser(dto)
    }

    // MARK: - Private

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
