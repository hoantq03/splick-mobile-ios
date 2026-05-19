import Foundation
import SplickDomain

public protocol AuthRepositoryProtocol: Sendable {
    func login(email: String, password: String) async throws -> AuthSession
    func requestEmailOtp(email: String) async throws
    func register(
        email: String,
        username: String,
        password: String,
        otpCode: String,
        displayName: String?
    ) async throws -> AuthSession
    func refreshToken(_ refreshToken: String) async throws -> AuthSession
    /// Revokes the session on the server when possible, then clears local credentials.
    func logout() async
    func getCurrentUser() async throws -> User
}
