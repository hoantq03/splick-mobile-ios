import SwiftUI

public struct ChatGroupManagementActions: Sendable {
    public var fetchMembers: @Sendable (UUID) async throws -> [GroupChatMember]
    public var updateGroupAvatar: @Sendable (UUID, Data) async throws -> String
    public var deleteGroup: @Sendable (UUID) async throws -> Void

    public init(
        fetchMembers: @escaping @Sendable (UUID) async throws -> [GroupChatMember],
        updateGroupAvatar: @escaping @Sendable (UUID, Data) async throws -> String,
        deleteGroup: @escaping @Sendable (UUID) async throws -> Void
    ) {
        self.fetchMembers = fetchMembers
        self.updateGroupAvatar = updateGroupAvatar
        self.deleteGroup = deleteGroup
    }

    public static let disabled = ChatGroupManagementActions(
        fetchMembers: { _ in [] },
        updateGroupAvatar: { _, _ in "" },
        deleteGroup: { _ in }
    )
}

private struct ChatGroupManagementActionsKey: EnvironmentKey {
    static let defaultValue = ChatGroupManagementActions.disabled
}

public extension EnvironmentValues {
    var chatGroupManagementActions: ChatGroupManagementActions {
        get { self[ChatGroupManagementActionsKey.self] }
        set { self[ChatGroupManagementActionsKey.self] = newValue }
    }
}
