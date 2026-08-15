import XCTest
@testable import FeatureMessaging
import SplickDomain

final class MessageReadReceiptPresentationTests: XCTestCase {
    func test_latestReadOutgoingMessageId_returnsNewestReadOnly() {
        let currentUserId = UUID()
        let peerId = UUID()
        let messages = [
            ChatMessage(
                id: UUID(),
                conversationId: UUID(),
                senderId: currentUserId,
                body: "a",
                clientMessageId: UUID(),
                createdAt: Date(timeIntervalSince1970: 1),
                deliveryStatus: .read
            ),
            ChatMessage(
                id: UUID(),
                conversationId: UUID(),
                senderId: peerId,
                body: "b",
                clientMessageId: UUID(),
                createdAt: Date(timeIntervalSince1970: 2),
                deliveryStatus: .sent
            ),
            ChatMessage(
                id: UUID(),
                conversationId: UUID(),
                senderId: currentUserId,
                body: "c",
                clientMessageId: UUID(),
                createdAt: Date(timeIntervalSince1970: 3),
                deliveryStatus: .read
            ),
        ]

        let latest = MessageReadReceiptPresentation.latestReadOutgoingMessageId(
            in: messages,
            currentUserId: currentUserId
        )
        XCTAssertEqual(latest, messages[2].id)
    }
}
