import Foundation

/// Viewer role for a group conversation thread (current user).
public enum GroupChatViewerRole: Equatable, Sendable {
    case owner
    case member
    /// Left or was removed; thread is read-only.
    case removed
}

/// Available actions in a group chat thread for the current viewer.
public struct GroupChatThreadCapabilities: Equatable, Sendable {
    public let canSearch: Bool
    public let canManageNotifications: Bool
    public let canChangeAvatar: Bool
    public let canRename: Bool
    public let canManageMembers: Bool
    public let canInviteMembers: Bool
    public let canLeave: Bool
    /// Permanently delete the social group (owner only).
    public let canDisbandGroup: Bool
    public let canDeleteConversation: Bool
    /// Reply, react, swipe-to-reply, composer.
    public let canInteractWithMessages: Bool

    public static func resolve(
        isGroup: Bool,
        isRemoved: Bool,
        isOwner: Bool
    ) -> GroupChatThreadCapabilities {
        guard isGroup else {
            return .directDefaults
        }
        if isRemoved {
            return .removed
        }
        return isOwner ? .owner : .member
    }

    public static func forRole(_ role: GroupChatViewerRole) -> GroupChatThreadCapabilities {
        switch role {
        case .owner: return .owner
        case .member: return .member
        case .removed: return .removed
        }
    }

    public static let owner = GroupChatThreadCapabilities(
        canSearch: true,
        canManageNotifications: true,
        canChangeAvatar: true,
        canRename: true,
        canManageMembers: true,
        canInviteMembers: true,
        canLeave: true,
        canDisbandGroup: true,
        canDeleteConversation: true,
        canInteractWithMessages: true
    )

    public static let member = GroupChatThreadCapabilities(
        canSearch: true,
        canManageNotifications: true,
        canChangeAvatar: false,
        canRename: false,
        canManageMembers: true,
        canInviteMembers: true,
        canLeave: true,
        canDisbandGroup: false,
        canDeleteConversation: true,
        canInteractWithMessages: true
    )

    public static let removed = GroupChatThreadCapabilities(
        canSearch: true,
        canManageNotifications: true,
        canChangeAvatar: false,
        canRename: false,
        canManageMembers: false,
        canInviteMembers: false,
        canLeave: false,
        canDisbandGroup: false,
        canDeleteConversation: true,
        canInteractWithMessages: false
    )

    /// Direct chats ignore group-only flags; interaction is gated elsewhere (blocked).
    public static let directDefaults = GroupChatThreadCapabilities(
        canSearch: true,
        canManageNotifications: true,
        canChangeAvatar: false,
        canRename: false,
        canManageMembers: false,
        canInviteMembers: false,
        canLeave: false,
        canDisbandGroup: false,
        canDeleteConversation: true,
        canInteractWithMessages: true
    )
}
