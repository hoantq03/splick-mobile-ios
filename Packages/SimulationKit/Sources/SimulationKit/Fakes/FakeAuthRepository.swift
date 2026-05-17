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
        logger.log("Login attempt: \(email)")

        try await Task.sleep(for: .milliseconds(300))

        guard let entry = users[email] else {
            logger.failure("Login failed: user not found")
            throw AuthError.invalidCredentials
        }

        guard entry.password == password else {
            logger.failure("Login failed: wrong password")
            throw AuthError.invalidCredentials
        }

        let token = AuthToken(
            accessToken: "fake-access-\(UUID().uuidString.prefix(8))",
            refreshToken: "fake-refresh-\(UUID().uuidString.prefix(8))",
            expiresIn: 3600,
            tokenType: "Bearer"
        )
        let session = AuthSession(user: entry.user, token: token)
        currentSession = session

        logger.success("Login successful: \(entry.user.username)")
        return session
    }

    public func register(email: String, username: String, password: String) async throws -> AuthSession {
        logger.log("Register attempt: \(email) / @\(username)")

        try await Task.sleep(for: .milliseconds(500))

        guard users[email] == nil else {
            logger.failure("Register failed: email exists")
            throw AuthError.emailAlreadyExists
        }

        let newUser = User(
            id: UUID(),
            email: email,
            username: username,
            displayName: username.capitalized,
            avatarURL: nil,
            createdAt: .now
        )
        users[email] = (password: password, user: newUser)

        let token = AuthToken(
            accessToken: "fake-access-\(UUID().uuidString.prefix(8))",
            refreshToken: "fake-refresh-\(UUID().uuidString.prefix(8))",
            expiresIn: 3600,
            tokenType: "Bearer"
        )
        let session = AuthSession(user: newUser, token: token)
        currentSession = session

        logger.success("Registration successful: @\(username)")
        return session
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
