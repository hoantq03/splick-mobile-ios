import Foundation

public struct AuthToken: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int
    public let tokenType: String

    public init(
        accessToken: String,
        refreshToken: String,
        expiresIn: Int,
        tokenType: String = "Bearer"
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.tokenType = tokenType
    }
}

public struct AuthSession: Equatable, Sendable {
    public let user: User
    public let token: AuthToken

    public init(user: User, token: AuthToken) {
        self.user = user
        self.token = token
    }
}
