import Foundation
import SplickDomain
import FeatureAuth
import Common

public actor FakeAuthRepository: AuthRepositoryProtocol {
    private var users: [String: (password: String, user: User)] = [:]
    private var currentSession: AuthSession?
    private let logger: StateLogger

    public init(logger: StateLogger) {
        self.logger = logger
    }

    public func seed() {
        let testUser = User(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            email: "test@splick.app",
            username: "namtran",
            displayName: "Nam Tran",
            avatarURL: nil,
            createdAt: Date()
        )
        users["test@splick.app"] = (password: "password123", user: testUser)

        let user2 = User(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            email: "linh@splick.app",
            username: "linhpham",
            displayName: "Linh Pham",
            avatarURL: nil,
            createdAt: Date()
        )
        users["linh@splick.app"] = (password: "password123", user: user2)

        logger.log("Seeded \(users.count) test users")
    }

    public func login(email: String, password: String) async throws -> AuthSession {
        logger.log("Mock login: \(email)")
        try await Task.sleep(for: .milliseconds(200))
        let session = makeSession(email: email, username: nil)
        currentSession = session
        logger.success("Mock login successful: \(session.user.username)")
        return session
    }

    public func register(email: String, username: String, password: String) async throws -> AuthSession {
        logger.log("Mock register: \(email) / @\(username)")
        try await Task.sleep(for: .milliseconds(300))
        let session = makeSession(email: email, username: username)
        users[email] = (password: password, user: session.user)
        currentSession = session
        logger.success("Mock registration successful: @\(session.user.username)")
        return session
    }

    private func makeSession(email: String, username: String?) -> AuthSession {
        let resolvedEmail = email.isEmpty ? "dev@splick.app" : email
        let resolvedUsername = username ?? resolvedEmail.split(separator: "@").first.map(String.init) ?? "splickuser"
        let user = User(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            email: resolvedEmail,
            username: resolvedUsername,
            displayName: resolvedUsername.capitalized,
            avatarURL: nil,
            createdAt: .now
        )
        let token = AuthToken(
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token",
            expiresIn: 3600,
            tokenType: "Bearer"
        )
        return AuthSession(user: user, token: token)
    }

    public func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        logger.log("Token refresh requested")
        try await Task.sleep(for: .milliseconds(200))

        return AuthToken(
            accessToken: "fake-access-refreshed-\(UUID().uuidString.prefix(8))",
            refreshToken: "fake-refresh-new-\(UUID().uuidString.prefix(8))",
            expiresIn: 3600,
            tokenType: "Bearer"
        )
    }

    public func logout() async throws {
        logger.log("Logout")
        currentSession = nil
        logger.success("Session cleared")
    }

    public func getCurrentUser() async throws -> User {
        guard let session = currentSession else {
            throw NetworkError.unauthorized
        }
        return session.user
    }
}
