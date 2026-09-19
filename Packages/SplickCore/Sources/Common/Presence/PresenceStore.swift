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
        guard states[state.userId] != state else { return }
        states[state.userId] = state
    }

    public func apply(userId: UUID, isOnline: Bool, lastSeenAt: Date?) {
        let existing = states[userId]
        let next = UserPresenceState(
            userId: userId,
            isOnline: isOnline,
            lastSeenAt: lastSeenAt ?? existing?.lastSeenAt
        )
        guard existing != next else { return }
        states[userId] = next
    }

    public func applyBulk(_ snapshots: [UserPresenceState]) {
        var next = states
        var changed = false
        for snapshot in snapshots where next[snapshot.userId] != snapshot {
            next[snapshot.userId] = snapshot
            changed = true
        }
        guard changed else { return }
        states = next
    }

    public func clear(userId: UUID) {
        guard states[userId] != nil else { return }
        states.removeValue(forKey: userId)
    }

    /// Optional peer fields: ignore empty snapshots; never OR-sticky online.
    public func mergeFromPeer(userId: UUID, isOnline: Bool?, lastSeenAt: Date?) {
        guard isOnline != nil || lastSeenAt != nil else { return }
        let existing = states[userId]
        let next = UserPresenceState(
            userId: userId,
            isOnline: isOnline ?? existing?.isOnline ?? false,
            lastSeenAt: lastSeenAt ?? existing?.lastSeenAt
        )
        guard existing != next else { return }
        states[userId] = next
    }
}
