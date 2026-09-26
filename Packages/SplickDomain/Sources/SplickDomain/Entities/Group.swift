import Foundation

public struct Group: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let inviteCode: String
    public let description: String?
    public let avatarURL: URL?
    public let members: [UserSummary]
    public let memberCount: Int
    public let createdBy: UUID
    public let createdAt: Date

    public init(
        id: UUID,
        name: String,
        inviteCode: String,
        description: String? = nil,
        avatarURL: URL? = nil,
        members: [UserSummary] = [],
        memberCount: Int? = nil,
        createdBy: UUID,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.description = description
        self.avatarURL = avatarURL
        self.members = members
        self.memberCount = memberCount ?? members.count
        self.createdBy = createdBy
        self.createdAt = createdAt
    }
}
