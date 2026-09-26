import XCTest
import SplickDomain
@testable import FeatureMessaging

final class MessagingWsEventDecoderTests: XCTestCase {

    func testDecodeInvalidJsonReturnsNil() {
        let invalidData = "not a json".data(using: .utf8)!
        let event = MessagingWsEventDecoder.decode(invalidData)
        XCTAssertNil(event)
    }

    func testDecodeUnknownTypeReturnsNil() {
        let json = """
        { "type": "unknown.event.type" }
        """
        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        XCTAssertNil(event)
    }

    func testDecodeNewMessageEventSuccess() {
        let convId = UUID()
        let msgId = UUID()
        let senderId = UUID()
        let clientMsgId = UUID()
        let mediaId = UUID()

        let json = """
        {
            "type": "message.new",
            "conversationId": "\(convId.uuidString)",
            "message": {
                "id": "\(msgId.uuidString)",
                "senderId": "\(senderId.uuidString)",
                "body": "Hello world!",
                "createdAt": "2026-09-20T08:00:00Z",
                "sequenceNo": 42,
                "clientMessageId": "\(clientMsgId.uuidString)",
                "attachments": [
                    {
                        "mediaId": "\(mediaId.uuidString)",
                        "url": "https://example.com/image.png",
                        "thumbnailUrl": "https://example.com/thumb.png"
                    },
                    {
                        "url": "::invalid-url::"
                    }
                ],
                "type": "USER",
                "senderDisplayName": "Alice"
            }
        }
        """

        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        XCTAssertNotNil(event)

        guard case let .newMessage(conversationId, message) = event else {
            XCTFail("Expected .newMessage event")
            return
        }

        XCTAssertEqual(conversationId, convId)
        XCTAssertEqual(message.id, msgId)
        XCTAssertEqual(message.senderId, senderId)
        XCTAssertEqual(message.senderDisplayName, "Alice")
        XCTAssertEqual(message.body, "Hello world!")
        XCTAssertEqual(message.sequenceNo, 42)
        XCTAssertEqual(message.clientMessageId, clientMsgId)
        XCTAssertEqual(message.imageAttachments.count, 2)
        XCTAssertEqual(message.imageAttachments.first?.mediaId, mediaId)
        XCTAssertEqual(message.imageAttachments.first?.url, URL(string: "https://example.com/image.png"))
        XCTAssertEqual(message.imageAttachments.first?.thumbnailURL, URL(string: "https://example.com/thumb.png"))
        XCTAssertEqual(message.type, .user)
    }

    func testDecodeNewMessageWithDefaultFallbacks() {
        let convId = UUID()
        let msgId = UUID()
        let senderId = UUID()

        let json = """
        {
            "type": "message.new",
            "conversationId": "\(convId.uuidString)",
            "message": {
                "id": "\(msgId.uuidString)",
                "senderId": "\(senderId.uuidString)",
                "body": "Fallback test",
                "createdAt": "2026-09-20T08:00:00Z"
            }
        }
        """

        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        guard case let .newMessage(conversationId, message) = event else {
            XCTFail("Expected .newMessage")
            return
        }

        XCTAssertEqual(conversationId, convId)
        XCTAssertEqual(message.id, msgId)
        XCTAssertEqual(message.sequenceNo, 0)
        XCTAssertNotNil(message.clientMessageId)
        XCTAssertTrue(message.imageAttachments.isEmpty)
        XCTAssertEqual(message.type, .user)
    }

    func testDecodeNewMessageInvalidPayloadReturnsNil() {
        let json = """
        {
            "type": "message.new",
            "conversationId": "invalid-uuid"
        }
        """
        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        XCTAssertNil(event)
    }

    func testDecodeReadReceipt() {
        let convId = UUID()
        let readerId = UUID()
        let upToMsgId = UUID()

        let json = """
        {
            "type": "message.read",
            "conversationId": "\(convId.uuidString)",
            "readerId": "\(readerId.uuidString)",
            "upToMessageId": "\(upToMsgId.uuidString)",
            "upToSequence": 100
        }
        """

        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        guard case let .readReceipt(cId, rId, uId, seq) = event else {
            XCTFail("Expected .readReceipt")
            return
        }
        XCTAssertEqual(cId, convId)
        XCTAssertEqual(rId, readerId)
        XCTAssertEqual(uId, upToMsgId)
        XCTAssertEqual(seq, 100)
    }

    func testDecodeReadReceiptInvalidReturnsNil() {
        let json = """
        {
            "type": "message.read",
            "conversationId": "invalid"
        }
        """
        XCTAssertNil(MessagingWsEventDecoder.decode(json.data(using: .utf8)!))
    }

    func testDecodeDeliveryAck() {
        let convId = UUID()
        let msgId = UUID()

        let json = """
        {
            "type": "message.delivered",
            "conversationId": "\(convId.uuidString)",
            "messageId": "\(msgId.uuidString)"
        }
        """

        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        guard case let .deliveryAck(cId, mId) = event else {
            XCTFail("Expected .deliveryAck")
            return
        }
        XCTAssertEqual(cId, convId)
        XCTAssertEqual(mId, msgId)
    }

    func testDecodeDeliveryAckInvalidReturnsNil() {
        let json = """
        {
            "type": "message.delivered",
            "conversationId": "invalid"
        }
        """
        XCTAssertNil(MessagingWsEventDecoder.decode(json.data(using: .utf8)!))
    }

    func testDecodeTyping() {
        let convId = UUID()
        let userId = UUID()

        let json = """
        {
            "type": "typing",
            "conversationId": "\(convId.uuidString)",
            "userId": "\(userId.uuidString)",
            "typing": true
        }
        """

        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        guard case let .typing(cId, uId, isTyping) = event else {
            XCTFail("Expected .typing")
            return
        }
        XCTAssertEqual(cId, convId)
        XCTAssertEqual(uId, userId)
        XCTAssertTrue(isTyping)
    }

    func testDecodeTypingInvalidReturnsNil() {
        let json = """
        {
            "type": "typing",
            "userId": "not-a-uuid"
        }
        """
        XCTAssertNil(MessagingWsEventDecoder.decode(json.data(using: .utf8)!))
    }

    func testDecodeMessageEdited() {
        let convId = UUID()
        let msgId = UUID()
        let senderId = UUID()

        let json = """
        {
            "type": "message.edited",
            "conversationId": "\(convId.uuidString)",
            "messageId": "\(msgId.uuidString)",
            "senderId": "\(senderId.uuidString)",
            "body": "Edited body content",
            "editedAt": "2026-09-20T08:05:00Z"
        }
        """

        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        guard case let .messageEdited(cId, mId, sId, body, editedAt) = event else {
            XCTFail("Expected .messageEdited")
            return
        }
        XCTAssertEqual(cId, convId)
        XCTAssertEqual(mId, msgId)
        XCTAssertEqual(sId, senderId)
        XCTAssertEqual(body, "Edited body content")
        XCTAssertNotNil(editedAt)
    }

    func testDecodeMessageEditedInvalidReturnsNil() {
        let json = """
        {
            "type": "message.edited",
            "conversationId": "invalid"
        }
        """
        XCTAssertNil(MessagingWsEventDecoder.decode(json.data(using: .utf8)!))
    }

    func testDecodeMessageRecalled() {
        let convId = UUID()
        let msgId = UUID()
        let senderId = UUID()

        let json = """
        {
            "type": "message.recalled",
            "conversationId": "\(convId.uuidString)",
            "messageId": "\(msgId.uuidString)",
            "senderId": "\(senderId.uuidString)"
        }
        """

        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        guard case let .messageRecalled(cId, mId, sId) = event else {
            XCTFail("Expected .messageRecalled")
            return
        }
        XCTAssertEqual(cId, convId)
        XCTAssertEqual(mId, msgId)
        XCTAssertEqual(sId, senderId)
    }

    func testDecodeMessageRecalledInvalidReturnsNil() {
        let json = """
        {
            "type": "message.recalled",
            "messageId": "not-a-uuid"
        }
        """
        XCTAssertNil(MessagingWsEventDecoder.decode(json.data(using: .utf8)!))
    }

    func testDecodePresenceWithFractionalSecondsAndOnline() {
        let userId = UUID()
        let json = """
        {
            "type": "presence",
            "userId": "\(userId.uuidString)",
            "online": true,
            "lastSeenAt": "2026-09-20T08:30:00.123Z"
        }
        """

        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        guard case let .presence(uId, isOnline, lastSeenAt) = event else {
            XCTFail("Expected .presence")
            return
        }
        XCTAssertEqual(uId, userId)
        XCTAssertTrue(isOnline)
        XCTAssertNotNil(lastSeenAt)
    }

    func testDecodePresenceWithIsOnlineAndLongDateString() {
        let userId = UUID()
        // String longer than 24 chars with fractional microseconds
        let json = """
        {
            "type": "presence",
            "userId": "\(userId.uuidString)",
            "isOnline": false,
            "lastSeenAt": "2026-09-20T08:30:00.123456789+00:00"
        }
        """

        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        guard case let .presence(uId, isOnline, lastSeenAt) = event else {
            XCTFail("Expected .presence")
            return
        }
        XCTAssertEqual(uId, userId)
        XCTAssertFalse(isOnline)
        XCTAssertNotNil(lastSeenAt)
    }

    func testDecodePresenceWithStandardIsoDate() {
        let userId = UUID()
        let json = """
        {
            "type": "presence",
            "userId": "\(userId.uuidString)",
            "lastSeenAt": "2026-09-20T08:30:00Z"
        }
        """

        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        guard case let .presence(uId, isOnline, lastSeenAt) = event else {
            XCTFail("Expected .presence")
            return
        }
        XCTAssertEqual(uId, userId)
        XCTAssertFalse(isOnline) // default false
        XCTAssertNotNil(lastSeenAt)
    }

    func testDecodePresenceWithInvalidLastSeenAt() {
        let userId = UUID()
        let json = """
        {
            "type": "presence",
            "userId": "\(userId.uuidString)",
            "lastSeenAt": "not-a-date"
        }
        """

        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        guard case let .presence(uId, isOnline, lastSeenAt) = event else {
            XCTFail("Expected .presence")
            return
        }
        XCTAssertEqual(uId, userId)
        XCTAssertFalse(isOnline)
        XCTAssertNil(lastSeenAt)
    }

    func testDecodePresenceInvalidReturnsNil() {
        let json = """
        {
            "type": "presence",
            "userId": "not-valid"
        }
        """
        XCTAssertNil(MessagingWsEventDecoder.decode(json.data(using: .utf8)!))
    }

    func testDecodeGroupMemberRemoved() {
        let convId = UUID()
        let userId = UUID()

        let json = """
        {
            "type": "group.member_removed",
            "conversationId": "\(convId.uuidString)",
            "removedUserId": "\(userId.uuidString)",
            "selfLeave": true
        }
        """

        let event = MessagingWsEventDecoder.decode(json.data(using: .utf8)!)
        guard case let .groupMemberRemoved(cId, uId, selfLeave) = event else {
            XCTFail("Expected .groupMemberRemoved")
            return
        }
        XCTAssertEqual(cId, convId)
        XCTAssertEqual(uId, userId)
        XCTAssertTrue(selfLeave)
    }

    func testDecodeGroupMemberRemovedInvalidReturnsNil() {
        let json = """
        {
            "type": "group.member_removed",
            "conversationId": "invalid"
        }
        """
        XCTAssertNil(MessagingWsEventDecoder.decode(json.data(using: .utf8)!))
    }
}
