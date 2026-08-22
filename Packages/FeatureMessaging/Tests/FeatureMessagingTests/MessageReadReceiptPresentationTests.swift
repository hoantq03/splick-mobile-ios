import XCTest
@testable import FeatureMessaging
import SplickDomain

final class MessageReadReceiptPresentationTests: XCTestCase {
    private let me = UUID()
    private let peer = UUID()
    private let conversationId = UUID()

    func test_selfReceiptDoesNotMarkRead() {
        let message = makeOutgoing(id: UUID(), sequence: 1, status: .delivered)
        let next = MessageReadReceiptPresentation.applyingReadReceipt(
            to: [message],
            currentUserId: me,
            readerId: me,
            upToMessageId: message.id,
            upToSequence: 1
        )
        XCTAssertNil(next)
    }

    func test_peerReceiptMarksOutgoingUpToCursor() {
        let first = makeOutgoing(id: UUID(), sequence: 1, status: .delivered)
        let second = makeOutgoing(id: UUID(), sequence: 2, status: .sent)
        let third = makeOutgoing(id: UUID(), sequence: 3, status: .sent)
        let next = MessageReadReceiptPresentation.applyingReadReceipt(
            to: [first, second, third],
            currentUserId: me,
            readerId: peer,
            upToMessageId: second.id,
            upToSequence: 2
        )
        XCTAssertEqual(next?[0].deliveryStatus, .read)
        XCTAssertEqual(next?[1].deliveryStatus, .read)
        XCTAssertEqual(next?[2].deliveryStatus, .sent)
        XCTAssertEqual(
            MessageReadReceiptPresentation.latestReadOutgoingMessageId(in: next ?? [], currentUserId: me),
            second.id
        )
    }

    private func makeOutgoing(id: UUID, sequence: Int64, status: MessageDeliveryStatus) -> ChatMessage {
        ChatMessage(
            id: id,
            conversationId: conversationId,
            senderId: me,
            body: "hi",
            clientMessageId: id,
            createdAt: Date(timeIntervalSince1970: TimeInterval(sequence)),
            sequenceNo: sequence,
            deliveryStatus: status
        )
    }
}
