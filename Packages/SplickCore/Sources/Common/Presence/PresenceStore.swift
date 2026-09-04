import Combine
import Foundation

@MainActor
public final class PresenceStore: ObservableObject {
    @Published public private(set) var states: [UUID: UserPresenceState] = [:]

    public init() {}

    public func state(for userId: UUID) -> UserPresenceState? {
        states[userId]
    }

    public func apply(_ state: UserPresenceState) {
        states[state.userId] = state
    }

    public func apply(userId: UUID, isOnline: Bool, lastSeenAt: Date?) {
        let existing = states[userId]
        states[userId] = UserPresenceState(
            userId: userId,
            isOnline: isOnline,
            lastSeenAt: lastSeenAt ?? existing?.lastSeenAt
        )
    }

    public func applyBulk(_ snapshots: [UserPresenceState]) {
        for snapshot in snapshots {
            apply(snapshot)
        }
    }

    /// Optional peer fields: ignore empty snapshots; never OR-sticky online.
    public func mergeFromPeer(userId: UUID, isOnline: Bool?, lastSeenAt: Date?) {
        guard isOnline != nil || lastSeenAt != nil else { return }
        let existing = states[userId]
        states[userId] = UserPresenceState(
            userId: userId,
            isOnline: isOnline ?? existing?.isOnline ?? false,
            lastSeenAt: lastSeenAt ?? existing?.lastSeenAt
        )
    }
}
