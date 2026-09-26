import Foundation

/// Snapshot of still-open incoming friend requests, used to hide Accept/Reject
/// on historical `FRIEND_REQUEST_SENT` notifications after the request is gone.
public struct PendingIncomingFriendRequests: Equatable, Sendable {
    public let requestIds: Set<UUID>
    public let requesterIds: Set<UUID>
    public let requestIdByRequester: [UUID: UUID]

    public init(requestIdByRequester: [UUID: UUID]) {
        self.requestIdByRequester = requestIdByRequester
        self.requestIds = Set(requestIdByRequester.values)
        self.requesterIds = Set(requestIdByRequester.keys)
    }

    public init(requestIds: Set<UUID>, requesterIds: Set<UUID>, requestIdByRequester: [UUID: UUID] = [:]) {
        self.requestIds = requestIds
        self.requesterIds = requesterIds
        self.requestIdByRequester = requestIdByRequester
    }
}

public enum FriendRequestInboxActionPolicy {
    /// Buttons stay only while the request is still pending (or pending state is unknown).
    public static func shouldShowRespondActions(
        for notification: AppNotification,
        hasStoredOutcome: Bool,
        pendingIncoming: PendingIncomingFriendRequests?,
        staleRequestIds: Set<UUID> = []
    ) -> Bool {
        guard notification.type == .friendRequestSent else { return false }
        if hasStoredOutcome { return false }
        if staleRequestIds.contains(notification.id) { return false }
        if let requestId = notification.referenceId, staleRequestIds.contains(requestId) {
            return false
        }
        guard let pendingIncoming else {
            return notification.referenceId != nil
        }
        if let requestId = notification.referenceId {
            return pendingIncoming.requestIds.contains(requestId)
        }
        if let actorId = notification.actorUserId {
            return pendingIncoming.requesterIds.contains(actorId)
        }
        return false
    }
}
