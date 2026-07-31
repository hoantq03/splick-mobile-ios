import XCTest
@testable import FeatureMessaging
import SplickDomain

@MainActor
final class MessageThreadCacheTests: XCTestCase {

    func test_lruEvictsOldestConversation() {
        let cache = MessageThreadCache(capacity: 2)
        let ids = (0..<3).map { _ in UUID() }

        for (index, id) in ids.enumerated() {
            cache.store(
                conversationId: id,
                messages: [
                    ChatMessage(
                        id: UUID(),
                        conversationId: id,
                        senderId: UUID(),
                        body: "c\(index)",
                        clientMessageId: UUID(),
                        createdAt: .now
                    )
                ],
                highestLoadedPage: 0,
                hasMoreMessages: false
            )
        }

        XCTAssertNil(cache.entry(for: ids[0]), "Oldest entry should be evicted")
        XCTAssertNotNil(cache.entry(for: ids[1]))
        XCTAssertNotNil(cache.entry(for: ids[2]))
    }

    func test_getTouchesOrderSoRecentlyReadSurvivesEviction() {
        let cache = MessageThreadCache(capacity: 2)
        let a = UUID()
        let b = UUID()
        let c = UUID()

        func store(_ id: UUID, body: String) {
            cache.store(
                conversationId: id,
                messages: [
                    ChatMessage(
                        id: UUID(),
                        conversationId: id,
                        senderId: UUID(),
                        body: body,
                        clientMessageId: UUID(),
                        createdAt: .now
                    )
                ],
                highestLoadedPage: 0,
                hasMoreMessages: false
            )
        }

        store(a, body: "a")
        store(b, body: "b")
        _ = cache.entry(for: a) // touch a → b becomes oldest
        store(c, body: "c")

        XCTAssertNotNil(cache.entry(for: a))
        XCTAssertNil(cache.entry(for: b))
        XCTAssertNotNil(cache.entry(for: c))
    }
}
