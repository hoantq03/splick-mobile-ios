import Foundation

public struct Group: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let avatarURL: URL?
    public let members: [UserSummary]
    public let createdBy: UUID
    public let createdAt: Date

    public init(
        id: UUID,
        name: String,
        description: String? = nil,
        avatarURL: URL? = nil,
        members: [UserSummary] = [],
        createdBy: UUID,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.avatarURL = avatarURL
        self.members = members
        self.createdBy = createdBy
        self.createdAt = createdAt
    }

    public var memberCount: Int { members.count }
}
