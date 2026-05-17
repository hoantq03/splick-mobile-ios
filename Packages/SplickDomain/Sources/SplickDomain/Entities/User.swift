import Foundation

public struct User: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let email: String
    public let username: String
    public let displayName: String
    public let avatarURL: URL?
    public let createdAt: Date

    public init(
        id: UUID,
        email: String,
        username: String,
        displayName: String,
        avatarURL: URL? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.createdAt = createdAt
    }
}

public struct UserSummary: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let username: String
    public let displayName: String
    public let avatarURL: URL?

    public init(id: UUID, username: String, displayName: String, avatarURL: URL? = nil) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
    }
}
