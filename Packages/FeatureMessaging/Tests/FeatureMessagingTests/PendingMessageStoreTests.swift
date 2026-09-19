import XCTest
@testable import FeatureMessaging
import SplickDomain
import Foundation

final class PendingMessageStoreTests: XCTestCase {

    private var tempURL: URL!
    private var store: PendingMessageStore!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-messages-\(UUID().uuidString).json")
        store = PendingMessageStore(fileURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func test_save_and_all_roundTrip() {
        let conversationId = UUID()
        let clientId = UUID()
        let attachment = MessageImageAttachment(
            mediaId: UUID(),
            url: URL(string: "https://example.com/a.jpg")!,
            thumbnailURL: nil
        )
        let pending = PendingOutboundMessage(
            conversationId: conversationId,
            clientMessageId: clientId,
            body: "Hello",
            imageAttachments: [attachment],
            replyToMessageId: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            status: .failed
        )

        store.save(pending)

        let all = store.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.clientMessageId, clientId)
        XCTAssertEqual(all.first?.body, "Hello")
        XCTAssertEqual(all.first?.imageAttachments.count, 1)
        XCTAssertEqual(store.all(for: conversationId).count, 1)
        XCTAssertTrue(store.all(for: UUID()).isEmpty)
    }

    func test_save_replacesSameClientMessageId() {
        let conversationId = UUID()
        let clientId = UUID()
        store.save(
            PendingOutboundMessage(
                conversationId: conversationId,
                clientMessageId: clientId,
                body: "First"
            )
        )
        store.save(
            PendingOutboundMessage(
                conversationId: conversationId,
                clientMessageId: clientId,
                body: "Second"
            )
        )

        XCTAssertEqual(store.all().count, 1)
        XCTAssertEqual(store.all().first?.body, "Second")
    }

    func test_remove_deletesEntry() {
        let clientId = UUID()
        store.save(
            PendingOutboundMessage(
                conversationId: UUID(),
                clientMessageId: clientId,
                body: "Gone"
            )
        )
        store.remove(clientMessageId: clientId)
        XCTAssertTrue(store.all().isEmpty)
    }
}
