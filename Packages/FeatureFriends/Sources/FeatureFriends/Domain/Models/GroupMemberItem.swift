import Foundation

public struct GroupMemberItem: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let userId: UUID
    public let username: String
    public let displayName: String
    public let avatarURL: URL?
    public let role: String
    public let status: String

    public init(
        id: UUID,
        userId: UUID,
        username: String,
        displayName: String,
        avatarURL: URL?,
        role: String,
        status: String
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.role = role
        self.status = status
    }

    public var isOwner: Bool {
        role.uppercased() == "OWNER"
    }

    public var isPending: Bool {
        status.uppercased() == "PENDING" || status.uppercased() == "PENDING_APPROVAL"
    }
}
