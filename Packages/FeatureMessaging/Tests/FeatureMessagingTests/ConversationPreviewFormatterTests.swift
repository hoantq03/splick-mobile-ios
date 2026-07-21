import XCTest
import SplickDomain
@testable import FeatureMessaging

final class ConversationPreviewFormatterTests: XCTestCase {
    private static let conversationId = UUID()
    private static let currentUserId = UUID()
    private static let otherUserId = UUID()

    func test_content_returnsEmoji_whenBodyContainsOnlyEmoji() {
        let message = makeMessage(body: "❤️ 👨‍👩‍👧‍👦")

        XCTAssertEqual(ConversationPreviewFormatter.content(for: message), .emoji)
    }

    func test_content_returnsText_whenBodyContainsTextAndEmoji() {
        let message = makeMessage(body: "Tuyệt quá ❤️")

        XCTAssertEqual(ConversationPreviewFormatter.content(for: message), .text("Tuyệt quá ❤️"))
    }

    func test_content_returnsImageCount_whenMessageHasAttachments() {
        let message = makeMessage(
            body: "",
            imageAttachments: [makeAttachment(), makeAttachment(), makeAttachment()]
        )

        XCTAssertEqual(ConversationPreviewFormatter.content(for: message), .images(3))
    }

    func test_senderLabel_returnsMe_whenCurrentUserSentMessage() {
        let message = makeMessage(senderId: Self.currentUserId, senderDisplayName: "Nguyễn Văn An")

        let result = ConversationPreviewFormatter.senderLabel(
            for: message,
            currentUserId: Self.currentUserId,
            meLabel: "Tôi",
            fallbackDisplayName: nil,
            unknownLabel: "Thành viên"
        )

        XCTAssertEqual(result, "Tôi")
    }

    func test_senderLabel_returnsOnlyGivenName_whenAnotherUserSentMessage() {
        let message = makeMessage(senderId: Self.otherUserId, senderDisplayName: "Nguyễn Văn An")

        let result = ConversationPreviewFormatter.senderLabel(
            for: message,
            currentUserId: Self.currentUserId,
            meLabel: "Tôi",
            fallbackDisplayName: nil,
            unknownLabel: "Thành viên"
        )

        XCTAssertEqual(result, "An")
    }

    private func makeMessage(
        senderId: UUID = otherUserId,
        senderDisplayName: String? = nil,
        body: String = "",
        imageAttachments: [MessageImageAttachment] = []
    ) -> ChatMessage {
        ChatMessage(
            id: UUID(),
            conversationId: Self.conversationId,
            senderId: senderId,
            senderDisplayName: senderDisplayName,
            body: body,
            clientMessageId: UUID(),
            createdAt: .now,
            imageAttachments: imageAttachments
        )
    }

    private func makeAttachment() -> MessageImageAttachment {
        MessageImageAttachment(
            mediaId: UUID(),
            url: URL(string: "https://example.com/image.jpg")!,
            thumbnailURL: nil
        )
    }
}
