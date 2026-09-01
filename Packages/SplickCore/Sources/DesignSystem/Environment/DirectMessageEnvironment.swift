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

private struct LeaveSocialGroupMembershipKey: EnvironmentKey {
    static let defaultValue: ((UUID) async throws -> Void)? = nil
}

private struct LeaveGroupConversationKey: EnvironmentKey {
    static let defaultValue: ((UUID) async throws -> Void)? = nil
}

private struct TransferGroupConversationAdminKey: EnvironmentKey {
    static let defaultValue: ((UUID, UUID) async throws -> Void)? = nil
}

private struct TransferSocialGroupOwnershipKey: EnvironmentKey {
    static let defaultValue: ((UUID, UUID) async throws -> Void)? = nil
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

    /// Leaves a social friends-group. Throws if the caller is the owner.
    public var leaveSocialGroupMembership: ((UUID) async throws -> Void)? {
        get { self[LeaveSocialGroupMembershipKey.self] }
        set { self[LeaveSocialGroupMembershipKey.self] = newValue }
    }

    /// Leaves the messaging conversation aligned with a social group id, if it exists.
    public var leaveGroupConversation: ((UUID) async throws -> Void)? {
        get { self[LeaveGroupConversationKey.self] }
        set { self[LeaveGroupConversationKey.self] = newValue }
    }

    /// Transfers messaging group admin to another member.
    public var transferGroupConversationAdmin: ((UUID, UUID) async throws -> Void)? {
        get { self[TransferGroupConversationAdminKey.self] }
        set { self[TransferGroupConversationAdminKey.self] = newValue }
    }

    /// Transfers social group ownership. Throws if the caller is not the owner.
    public var transferSocialGroupOwnership: ((UUID, UUID) async throws -> Void)? {
        get { self[TransferSocialGroupOwnershipKey.self] }
        set { self[TransferSocialGroupOwnershipKey.self] = newValue }
    }
}
