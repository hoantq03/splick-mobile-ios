import XCTest
@testable import FeatureMessaging
import Foundation
import Networking
import SplickDomain

final class MessagingWebSocketClientTests: XCTestCase {

    private let conversationId = UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000001")!
    private let messageId = UUID(uuidString: "bbbbbbbb-0000-0000-0000-000000000001")!
    private let senderId = UUID(uuidString: "cccccccc-0000-0000-0000-000000000001")!
    private let clientMessageId = UUID(uuidString: "dddddddd-0000-0000-0000-000000000001")!

    func test_decode_messageNew_includesSequenceAndClientMessageId() throws {
        let json = """
        {
          "type": "message.new",
          "conversationId": "\(conversationId.uuidString)",
          "message": {
            "id": "\(messageId.uuidString)",
            "senderId": "\(senderId.uuidString)",
            "body": "Hello",
            "createdAt": "2026-08-01T12:00:00.123Z",
            "sequenceNo": 42,
            "clientMessageId": "\(clientMessageId.uuidString)",
            "attachments": []
          }
        }
        """.data(using: .utf8)!

        let event = MessagingWsEventDecoder.decode(json)
        guard case .newMessage(let convId, let message)? = event else {
            return XCTFail("Expected newMessage event")
        }

        XCTAssertEqual(convId, conversationId)
        XCTAssertEqual(message.id, messageId)
        XCTAssertEqual(message.clientMessageId, clientMessageId)
        XCTAssertEqual(message.sequenceNo, 42)
        XCTAssertEqual(message.body, "Hello")
        XCTAssertGreaterThan(message.createdAt.timeIntervalSince1970, 0)
    }

    func test_decode_messageNew_fallsBackClientMessageIdWhenMissing() throws {
        let json = """
        {
          "type": "message.new",
          "conversationId": "\(conversationId.uuidString)",
          "message": {
            "id": "\(messageId.uuidString)",
            "senderId": "\(senderId.uuidString)",
            "body": "No client id",
            "createdAt": "2026-08-01T12:00:00.000Z",
            "sequenceNo": 7
          }
        }
        """.data(using: .utf8)!

        let event = MessagingWsEventDecoder.decode(json)
        guard case .newMessage(_, let message)? = event else {
            return XCTFail("Expected newMessage event")
        }

        XCTAssertNotEqual(message.clientMessageId, messageId)
        XCTAssertEqual(message.sequenceNo, 7)
    }

    func test_decode_readReceipt_includesOptionalSequence() throws {
        let readerId = UUID()
        let json = """
        {
          "type": "message.read",
          "conversationId": "\(conversationId.uuidString)",
          "readerId": "\(readerId.uuidString)",
          "upToMessageId": "\(messageId.uuidString)",
          "upToSequence": 99
        }
        """.data(using: .utf8)!

        let event = MessagingWsEventDecoder.decode(json)
        guard case .readReceipt(let convId, let reader, let upTo, let seq)? = event else {
            return XCTFail("Expected readReceipt")
        }

        XCTAssertEqual(convId, conversationId)
        XCTAssertEqual(reader, readerId)
        XCTAssertEqual(upTo, messageId)
        XCTAssertEqual(seq, 99)
    }

    func test_decode_typing_and_edited_and_recalled() throws {
        let userId = UUID()

        let typingJSON = """
        {"type":"typing","conversationId":"\(conversationId.uuidString)","userId":"\(userId.uuidString)","typing":true}
        """.data(using: .utf8)!
        guard case .typing(let tConv, let tUser, let isTyping)? = MessagingWsEventDecoder.decode(typingJSON) else {
            return XCTFail("Expected typing")
        }
        XCTAssertEqual(tConv, conversationId)
        XCTAssertEqual(tUser, userId)
        XCTAssertTrue(isTyping)

        let editedJSON = """
        {
          "type":"message.edited",
          "conversationId":"\(conversationId.uuidString)",
          "messageId":"\(messageId.uuidString)",
          "senderId":"\(senderId.uuidString)",
          "body":"Edited",
          "editedAt":"2026-08-01T12:01:00.000Z"
        }
        """.data(using: .utf8)!
        guard case .messageEdited(_, let editedId, _, let body)? = MessagingWsEventDecoder.decode(editedJSON) else {
            return XCTFail("Expected messageEdited")
        }
        XCTAssertEqual(editedId, messageId)
        XCTAssertEqual(body, "Edited")

        let recalledJSON = """
        {
          "type":"message.recalled",
          "conversationId":"\(conversationId.uuidString)",
          "messageId":"\(messageId.uuidString)",
          "senderId":"\(senderId.uuidString)"
        }
        """.data(using: .utf8)!
        guard case .messageRecalled(_, let recalledId, _)? = MessagingWsEventDecoder.decode(recalledJSON) else {
            return XCTFail("Expected messageRecalled")
        }
        XCTAssertEqual(recalledId, messageId)
    }

    func test_decode_groupMemberRemoved() throws {
        let removedUserId = UUID()
        let json = """
        {
          "type": "group.member_removed",
          "conversationId": "\(conversationId.uuidString)",
          "removedUserId": "\(removedUserId.uuidString)",
          "selfLeave": false
        }
        """.data(using: .utf8)!

        let event = MessagingWsEventDecoder.decode(json)
        guard case .groupMemberRemoved(let convId, let userId, let selfLeave)? = event else {
            return XCTFail("Expected groupMemberRemoved")
        }
        XCTAssertEqual(convId, conversationId)
        XCTAssertEqual(userId, removedUserId)
        XCTAssertFalse(selfLeave)
    }
}
