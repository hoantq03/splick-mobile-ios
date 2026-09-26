import Foundation

public struct GroupChatMember: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let username: String
    public let displayName: String
    public let avatarURL: URL?
    public let isOwner: Bool

    public init(
        id: UUID,
        userId: UUID,
        username: String,
        displayName: String,
        avatarURL: URL?,
        isOwner: Bool
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.isOwner = isOwner
    }
}
