import Foundation
import Testing
@testable import Common

@MainActor
struct PresenceStoreTests {
    @Test
    func applyOverwritesOnlineToOffline() {
        let store = PresenceStore()
        let userId = UUID()
        store.apply(userId: userId, isOnline: true, lastSeenAt: Date())
        store.apply(userId: userId, isOnline: false, lastSeenAt: Date())
        #expect(store.state(for: userId)?.isOnline == false)
    }

    @Test
    func applyBulkOverwritesPreviousOnline() {
        let store = PresenceStore()
        let userId = UUID()
        store.apply(userId: userId, isOnline: true, lastSeenAt: Date())
        store.applyBulk([
            UserPresenceState(userId: userId, isOnline: false, lastSeenAt: nil)
        ])
        #expect(store.state(for: userId)?.isOnline == false)
    }

    @Test
    func mergeFromPeerUsesIncomingOnlineWithoutStickyOr() {
        let store = PresenceStore()
        let userId = UUID()
        store.apply(userId: userId, isOnline: true, lastSeenAt: Date())
        store.mergeFromPeer(userId: userId, isOnline: false, lastSeenAt: Date())
        #expect(store.state(for: userId)?.isOnline == false)
    }
}
