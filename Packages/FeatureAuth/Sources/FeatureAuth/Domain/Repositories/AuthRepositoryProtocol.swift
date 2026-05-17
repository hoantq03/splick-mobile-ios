import Foundation
import SplickDomain

public protocol AuthRepositoryProtocol: Sendable {
    func login(email: String, password: String) async throws -> AuthSession
    func register(email: String, username: String, password: String) async throws -> AuthSession
    func refreshToken(_ refreshToken: String) async throws -> AuthToken
    func logout() async throws
    func getCurrentUser() async throws -> User
}
