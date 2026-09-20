import XCTest
@testable import SplickDomain

final class ChatMessageDomainTests: XCTestCase {
    func testChatMessagePropertiesAndSystemNotice() {
        let senderId = UUID()
        let convId = UUID()
        let now = Date()
        
        let userMsg = ChatMessage(
            id: UUID(),
            conversationId: convId,
            senderId: senderId,
            body: "Hello",
            clientMessageId: UUID(),
            createdAt: now,
            type: .user
        )
        XCTAssertFalse(userMsg.isSystemNotice)
        XCTAssertFalse(userMsg.isEdited)
        XCTAssertFalse(userMsg.recalled)
        
        let systemNotice = ChatMessage(
            id: UUID(),
            conversationId: convId,
            senderId: senderId,
            body: "Renamed group",
            clientMessageId: UUID(),
            createdAt: now,
            type: .groupRenamed
        )
        XCTAssertTrue(systemNotice.isSystemNotice)
        
        // System notices across all kinds
        let noticeTypes: [ChatMessageType] = [
            .groupMemberAdded, .groupMemberRemoved, .groupMemberLeft, .groupDeleted, .groupAdminTransferred
        ]
        for t in noticeTypes {
            let msg = ChatMessage(
                id: UUID(),
                conversationId: convId,
                senderId: senderId,
                body: "notice",
                clientMessageId: UUID(),
                createdAt: now,
                type: t
            )
            XCTAssertTrue(msg.isSystemNotice)
        }
    }

    func testEditAndRecallPermissions() {
        let senderId = UUID()
        let otherUserId = UUID()
        let convId = UUID()
        let now = Date()
        
        let freshMsg = ChatMessage(
            id: UUID(),
            conversationId: convId,
            senderId: senderId,
            body: "Test message",
            clientMessageId: UUID(),
            createdAt: now
        )
        
        XCTAssertTrue(freshMsg.isWithinEditRecallWindow(now: now.addingTimeInterval(60)))
        XCTAssertFalse(freshMsg.isWithinEditRecallWindow(now: now.addingTimeInterval(400))) // > 5 min
        
        // Editable & Recallable by sender
        XCTAssertTrue(freshMsg.isEditable(by: senderId, now: now.addingTimeInterval(30)))
        XCTAssertTrue(freshMsg.isRecallable(by: senderId, now: now.addingTimeInterval(30)))
        
        // Not editable by other user
        XCTAssertFalse(freshMsg.isEditable(by: otherUserId, now: now.addingTimeInterval(30)))
        XCTAssertFalse(freshMsg.isRecallable(by: otherUserId, now: now.addingTimeInterval(30)))
        
        // When empty body
        let emptyBodyMsg = ChatMessage(
            id: UUID(),
            conversationId: convId,
            senderId: senderId,
            body: "   ",
            clientMessageId: UUID(),
            createdAt: now
        )
        XCTAssertFalse(emptyBodyMsg.isEditable(by: senderId, now: now.addingTimeInterval(30)))
        
        // When recalled
        let recalledMsg = freshMsg.updatingAsRecalled()
        XCTAssertTrue(recalledMsg.recalled)
        XCTAssertTrue(recalledMsg.body.isEmpty)
        XCTAssertFalse(recalledMsg.isEditable(by: senderId, now: now.addingTimeInterval(30)))
        XCTAssertFalse(recalledMsg.isRecallable(by: senderId, now: now.addingTimeInterval(30)))
    }

    func testMessageUpdatesAndReactions() {
        let senderId = UUID()
        let u1 = UUID()
        let u2 = UUID()
        let convId = UUID()
        let now = Date()
        
        var msg = ChatMessage(
            id: UUID(),
            conversationId: convId,
            senderId: senderId,
            body: "Initial text",
            clientMessageId: UUID(),
            createdAt: now,
            deliveryStatus: .sending
        )
        
        msg = msg.updating(deliveryStatus: .sent)
        XCTAssertEqual(msg.deliveryStatus, .sent)
        
        msg = msg.updating(body: "Edited text", editedAt: now.addingTimeInterval(10))
        XCTAssertTrue(msg.isEdited)
        XCTAssertEqual(msg.body, "Edited text")
        
        // Reactions
        let r1 = Reaction(id: UUID(), emoji: "❤️", userId: u1)
        let r2 = Reaction(id: UUID(), emoji: "❤️", userId: u2)
        let r3 = Reaction(id: UUID(), emoji: "🔥", userId: u1)
        
        msg = msg.updating(reactions: [r1, r2, r3])
        XCTAssertEqual(msg.lastReactionEmoji(for: u1), "🔥")
        XCTAssertEqual(msg.lastReactionEmoji(for: u2), "❤️")
        XCTAssertNil(msg.lastReactionEmoji(for: UUID()))
        
        let counts = msg.reactionCounts()
        XCTAssertEqual(counts.first?.emoji, "❤️")
        XCTAssertEqual(counts.first?.count, 2)
        
        let insideOutOut = msg.reactionCountsInsideOut(isOutgoing: true)
        let insideOutIn = msg.reactionCountsInsideOut(isOutgoing: false)
        XCTAssertFalse(insideOutOut.isEmpty)
        XCTAssertFalse(insideOutIn.isEmpty)
        
        // When recalled, reactions return empty
        let recalled = msg.updatingAsRecalled()
        XCTAssertTrue(recalled.reactionCounts().isEmpty)
        XCTAssertTrue(recalled.reactionCountsInsideOut(isOutgoing: true).isEmpty)
        XCTAssertNil(recalled.lastReactionEmoji(for: u1))
        XCTAssertFalse(recalled.hasImageAttachments)
    }

    func testPostMediaItemAspectRatio() {
        let itemValid = PostMediaItem(
            mediaURL: URL(string: "https://example.com/p.jpg")!,
            mediaType: .image,
            widthPx: 1080,
            heightPx: 1920
        )
        XCTAssertNotNil(itemValid.aspectRatio)
        XCTAssertEqual(itemValid.aspectRatio!, 1080.0 / 1920.0, accuracy: 0.001)
        
        let itemInvalid = PostMediaItem(
            mediaURL: URL(string: "https://example.com/p.jpg")!,
            mediaType: .image,
            widthPx: 0,
            heightPx: 1920
        )
        XCTAssertNil(itemInvalid.aspectRatio)
    }
}
