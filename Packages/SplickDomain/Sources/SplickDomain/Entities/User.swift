import Foundation

public struct User: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let email: String
    public let username: String
    public let displayName: String
    public let avatarURL: URL?
    public let status: UserAccountStatus
    public let preferredLocale: String
    public let createdAt: Date

    public init(
        id: UUID,
        email: String,
        username: String,
        displayName: String,
        avatarURL: URL? = nil,
        status: UserAccountStatus = .active,
        preferredLocale: String = "vi",
        createdAt: Date = .now
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.status = status
        self.preferredLocale = preferredLocale
        self.createdAt = createdAt
    }
}

public struct UserSummary: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let username: String
    public let displayName: String
    /// Legal / profile display name when `displayName` shows a friend nickname.
    public let subtitle: String?
    public let avatarURL: URL?

    public init(
        id: UUID,
        username: String,
        displayName: String,
        subtitle: String? = nil,
        avatarURL: URL? = nil
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.subtitle = subtitle
        self.avatarURL = avatarURL
    }
}
