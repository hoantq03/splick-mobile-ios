import XCTest
@testable import FeatureMessaging
import SplickDomain

@MainActor
final class MessageThreadCacheTests: XCTestCase {

    private func makeIsolatedCache(capacity: Int) -> (MessageThreadCache, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("message-cache-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (MessageThreadCache(capacity: capacity, diskDirectory: directory), directory)
    }

    func test_lruEvictsOldestFromMemory_diskStillRestores() {
        let (cache, directory) = makeIsolatedCache(capacity: 2)
        defer { try? FileManager.default.removeItem(at: directory) }
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

        // Fresh instance — only disk, proves eviction left files behind.
        let reader = MessageThreadCache(capacity: 2, diskDirectory: directory)
        XCTAssertNotNil(reader.entry(for: ids[0]))
        XCTAssertEqual(reader.entry(for: ids[0])?.messages.first?.body, "c0")
        XCTAssertNotNil(reader.entry(for: ids[2]))
    }

    func test_getTouchesOrderSoRecentlyReadSurvivesEviction() {
        let (cache, directory) = makeIsolatedCache(capacity: 2)
        defer { try? FileManager.default.removeItem(at: directory) }
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
        _ = cache.entry(for: a) // touch a → b becomes oldest in memory
        store(c, body: "c")

        // a and c should be restorable; b was oldest in memory after touch but still on disk.
        XCTAssertEqual(cache.entry(for: a)?.messages.first?.body, "a")
        XCTAssertEqual(cache.entry(for: c)?.messages.first?.body, "c")
        XCTAssertEqual(cache.entry(for: b)?.messages.first?.body, "b")
    }

    func test_diskPersistsAcrossCacheInstances() {
        let (writer, directory) = makeIsolatedCache(capacity: 5)
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationId = UUID()
        let message = ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            senderId: UUID(),
            body: "Persisted",
            clientMessageId: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            sequenceNo: 12
        )

        writer.store(
            conversationId: conversationId,
            messages: [message],
            highestLoadedPage: 1,
            hasMoreMessages: true
        )

        let reader = MessageThreadCache(capacity: 5, diskDirectory: directory)
        let entry = reader.entry(for: conversationId)

        XCTAssertEqual(entry?.messages.first?.body, "Persisted")
        XCTAssertEqual(entry?.messages.first?.sequenceNo, 12)
        XCTAssertEqual(entry?.highestLoadedPage, 1)
        XCTAssertEqual(entry?.hasMoreMessages, true)
    }
}
