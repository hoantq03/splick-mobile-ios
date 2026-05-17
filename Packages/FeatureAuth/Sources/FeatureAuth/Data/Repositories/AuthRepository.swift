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
        let dto = LoginRequestDTO(email: email, password: password)
        let response: AuthResponseDTO = try await apiClient.request(AuthEndpoint.login(dto))
        try persistTokens(response)
        await tokenProvider.updateTokens(
            access: response.accessToken,
            refresh: response.refreshToken
        )
        return AuthMapper.toAuthSession(response)
    }

    public func register(email: String, username: String, password: String) async throws -> AuthSession {
        let dto = RegisterRequestDTO(email: email, username: username, password: password)
        let response: AuthResponseDTO = try await apiClient.request(AuthEndpoint.register(dto))
        try persistTokens(response)
        await tokenProvider.updateTokens(
            access: response.accessToken,
            refresh: response.refreshToken
        )
        return AuthMapper.toAuthSession(response)
    }

    public func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        let dto = RefreshTokenRequestDTO(refreshToken: refreshToken)
        let response: TokenResponseDTO = try await apiClient.request(AuthEndpoint.refreshToken(dto))
        try keychainService.saveString(response.accessToken, for: AppConstants.Keychain.accessTokenKey)
        try keychainService.saveString(response.refreshToken, for: AppConstants.Keychain.refreshTokenKey)
        await tokenProvider.updateTokens(access: response.accessToken, refresh: response.refreshToken)
        return AuthMapper.toAuthToken(response)
    }

    public func logout() async throws {
        try? await apiClient.request(AuthEndpoint.logout)
        try? keychainService.delete(for: AppConstants.Keychain.accessTokenKey)
        try? keychainService.delete(for: AppConstants.Keychain.refreshTokenKey)
        await tokenProvider.clearTokens()
    }

    public func getCurrentUser() async throws -> User {
        let dto: UserDTO = try await apiClient.request(AuthEndpoint.me)
        return AuthMapper.toUser(dto)
    }

    // MARK: - Private

    private func persistTokens(_ response: AuthResponseDTO) throws {
        try keychainService.saveString(response.accessToken, for: AppConstants.Keychain.accessTokenKey)
        try keychainService.saveString(response.refreshToken, for: AppConstants.Keychain.refreshTokenKey)
    }
}
