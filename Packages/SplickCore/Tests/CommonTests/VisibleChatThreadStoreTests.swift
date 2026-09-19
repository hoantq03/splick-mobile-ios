import Foundation
import Testing
@testable import Common

struct VisibleChatThreadStoreTests {
    @Test
    func matchesSetConversation() {
        let store = VisibleChatThreadStore()
        let conversationId = UUID()
        store.set(conversationId)
        #expect(store.matches(conversationId))
        store.clearIfMatching(conversationId)
        #expect(!store.matches(conversationId))
    }
}
