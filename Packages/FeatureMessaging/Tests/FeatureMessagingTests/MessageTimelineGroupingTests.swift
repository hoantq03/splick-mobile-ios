import XCTest
import SplickDomain
@testable import FeatureMessaging

final class MessageTimelineGroupingTests: XCTestCase {

    private static let senderA = UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000001")!
    private static let senderB = UUID(uuidString: "bbbbbbbb-0000-0000-0000-000000000001")!
    private static let conversationId = UUID(uuidString: "cccccccc-0000-0000-0000-000000000001")!

    private func makeMessage(
        senderId: UUID,
        createdAt: Date,
        body: String = "Hi"
    ) -> ChatMessage {
        ChatMessage(
            id: UUID(),
            conversationId: Self.conversationId,
            senderId: senderId,
            body: body,
            clientMessageId: UUID(),
            createdAt: createdAt
        )
    }

    func test_buildDisplayMessages_groupsSameSenderWithinFiveMinutes() {
        let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let t1 = t0.addingTimeInterval(60)
        let t2 = t0.addingTimeInterval(120)

        let messages = [
            makeMessage(senderId: Self.senderA, createdAt: t0, body: "1"),
            makeMessage(senderId: Self.senderA, createdAt: t1, body: "2"),
            makeMessage(senderId: Self.senderA, createdAt: t2, body: "3"),
        ]

        let display = MessageTimelineGrouping.buildDisplayMessages(from: messages)

        XCTAssertEqual(display.map(\.groupPosition), [.groupFirst, .groupMiddle, .groupLast])
        XCTAssertEqual(display.map(\.showsTimestamp), [false, false, true])
    }

    func test_buildDisplayMessages_splitsWhenGapExceedsFiveMinutes() {
        let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let t1 = t0.addingTimeInterval(301)

        let messages = [
            makeMessage(senderId: Self.senderA, createdAt: t0, body: "1"),
            makeMessage(senderId: Self.senderA, createdAt: t1, body: "2"),
        ]

        let display = MessageTimelineGrouping.buildDisplayMessages(from: messages)

        XCTAssertEqual(display.map(\.groupPosition), [.standalone, .standalone])
        XCTAssertEqual(display.map(\.showsTimestamp), [true, true])
    }

    func test_buildDisplayMessages_doesNotGroupDifferentSenders() {
        let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let t1 = t0.addingTimeInterval(30)

        let messages = [
            makeMessage(senderId: Self.senderA, createdAt: t0),
            makeMessage(senderId: Self.senderB, createdAt: t1),
        ]

        let display = MessageTimelineGrouping.buildDisplayMessages(from: messages)

        XCTAssertEqual(display.map(\.groupPosition), [.standalone, .standalone])
    }

    func test_buildDisplayMessages_rendersMultipleAttachmentsOnSingleMessage() {
        let attachment = MessageImageAttachment(
            mediaId: UUID(),
            url: URL(string: "https://example.com/a.jpg")!,
            thumbnailURL: nil
        )
        let second = MessageImageAttachment(
            mediaId: UUID(),
            url: URL(string: "https://example.com/b.jpg")!,
            thumbnailURL: nil
        )
        let third = MessageImageAttachment(
            mediaId: UUID(),
            url: URL(string: "https://example.com/c.jpg")!,
            thumbnailURL: nil
        )

        let messages = [
            ChatMessage(
                id: UUID(),
                conversationId: Self.conversationId,
                senderId: Self.senderA,
                body: "Caption",
                clientMessageId: UUID(),
                createdAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
                imageAttachments: [attachment, second, third]
            ),
        ]

        let display = MessageTimelineGrouping.buildDisplayMessages(from: messages)

        XCTAssertEqual(display.count, 1)
        XCTAssertEqual(display[0].imageAttachments.count, 3)
        XCTAssertEqual(display[0].message.body, "Caption")
    }
}
