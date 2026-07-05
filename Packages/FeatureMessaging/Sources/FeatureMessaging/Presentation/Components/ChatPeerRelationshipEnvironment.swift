import SwiftUI

public struct ChatPeerRelationshipActions: Sendable {
    public var fetchStatus: @Sendable (UUID) async -> ChatPeerRelationState
    public var blockUser: @Sendable (UUID) async throws -> Void
    public var unblockUser: @Sendable (UUID) async throws -> Void
    public var removeFriend: @Sendable (UUID) async throws -> Void
    public var addFriend: @Sendable (UUID) async throws -> Void
    public var acceptFriendRequest: @Sendable (UUID) async throws -> Void

    public init(
        fetchStatus: @escaping @Sendable (UUID) async -> ChatPeerRelationState,
        blockUser: @escaping @Sendable (UUID) async throws -> Void,
        unblockUser: @escaping @Sendable (UUID) async throws -> Void,
        removeFriend: @escaping @Sendable (UUID) async throws -> Void,
        addFriend: @escaping @Sendable (UUID) async throws -> Void,
        acceptFriendRequest: @escaping @Sendable (UUID) async throws -> Void
    ) {
        self.fetchStatus = fetchStatus
        self.blockUser = blockUser
        self.unblockUser = unblockUser
        self.removeFriend = removeFriend
        self.addFriend = addFriend
        self.acceptFriendRequest = acceptFriendRequest
    }

    public static let disabled = ChatPeerRelationshipActions(
        fetchStatus: { _ in .friends },
        blockUser: { _ in },
        unblockUser: { _ in },
        removeFriend: { _ in },
        addFriend: { _ in },
        acceptFriendRequest: { _ in }
    )
}

private struct ChatPeerRelationshipActionsKey: EnvironmentKey {
    static let defaultValue = ChatPeerRelationshipActions.disabled
}

public extension EnvironmentValues {
    var chatPeerRelationshipActions: ChatPeerRelationshipActions {
        get { self[ChatPeerRelationshipActionsKey.self] }
        set { self[ChatPeerRelationshipActionsKey.self] = newValue }
    }
}
