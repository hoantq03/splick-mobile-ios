import SwiftUI
import Foundation

/// Environment closure to open a direct message thread with a user.
/// Returns the conversationId if created/found, nil on failure.
private struct OpenDirectMessageKey: EnvironmentKey {
    static let defaultValue: ((UUID) async -> UUID?)? = nil
}

public struct OpenGroupChatRequest: Sendable {
    public let groupId: UUID
    public let name: String
    public let avatarURL: String?
    public let memberUserIds: [UUID]

    public init(groupId: UUID, name: String, avatarURL: String?, memberUserIds: [UUID]) {
        self.groupId = groupId
        self.name = name
        self.avatarURL = avatarURL
        self.memberUserIds = memberUserIds
    }
}

private struct OpenGroupChatKey: EnvironmentKey {
    static let defaultValue: ((OpenGroupChatRequest) async -> UUID?)? = nil
}

public struct InviteFriendsToGroupRequest: Identifiable, Sendable {
    public let groupId: UUID
    public let existingMemberIds: Set<UUID>

    public var id: UUID { groupId }

    public init(groupId: UUID, existingMemberIds: Set<UUID>) {
        self.groupId = groupId
        self.existingMemberIds = existingMemberIds
    }
}

private struct PresentInviteFriendsToGroupKey: EnvironmentKey {
    static let defaultValue: ((InviteFriendsToGroupRequest) -> Void)? = nil
}

private struct AddMembersToGroupConversationKey: EnvironmentKey {
    static let defaultValue: ((UUID, [UUID]) async -> Void)? = nil
}

extension EnvironmentValues {
    public var openDirectMessage: ((UUID) async -> UUID?)? {
        get { self[OpenDirectMessageKey.self] }
        set { self[OpenDirectMessageKey.self] = newValue }
    }

    /// Opens or creates the messaging thread aligned with a social group.
    public var openGroupChat: ((OpenGroupChatRequest) async -> UUID?)? {
        get { self[OpenGroupChatKey.self] }
        set { self[OpenGroupChatKey.self] = newValue }
    }

    /// Presents the shared “add members” picker for a social / group-chat id.
    public var presentInviteFriendsToGroup: ((InviteFriendsToGroupRequest) -> Void)? {
        get { self[PresentInviteFriendsToGroupKey.self] }
        set { self[PresentInviteFriendsToGroupKey.self] = newValue }
    }

    /// Adds invited users to an existing group conversation when one already exists.
    public var addMembersToGroupConversation: ((UUID, [UUID]) async -> Void)? {
        get { self[AddMembersToGroupConversationKey.self] }
        set { self[AddMembersToGroupConversationKey.self] = newValue }
    }
}
