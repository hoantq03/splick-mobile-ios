import XCTest
@testable import FeatureMessaging

final class MessagingTypingCopyTests: XCTestCase {
    func test_directUsesDisplayNameWithColon() {
        let peer = UUID()
        let label = MessagingTypingCopy.inboxPreview(
            userIds: [peer],
            nameForUserId: { _ in "Nam" },
            typing: "Composing..."
        )
        XCTAssertEqual(label, "Nam: Composing...")
    }

    func test_directFallsBackToPeerNameWhenLookupMisses() {
        let peer = UUID()
        let label = MessagingTypingCopy.inboxPreview(
            userIds: [peer],
            nameForUserId: { _ in nil },
            typing: "Composing...",
            fallbackName: "Peer"
        )
        XCTAssertEqual(label, "Peer: Composing...")
    }

    func test_groupUsesCommaSeparatedNames() {
        let first = UUID()
        let second = UUID()
        let names = [first: "Nam", second: "Lan"]
        let label = MessagingTypingCopy.inboxPreview(
            userIds: [first, second],
            nameForUserId: { names[$0] },
            typing: "Composing..."
        )
        XCTAssertEqual(label, "Nam, Lan: Composing...")
    }

    func test_stripTrailingEllipsis_removesDots() {
        XCTAssertEqual(
            MessagingTypingCopy.stripTrailingEllipsis("Nam: Đang soạn tin..."),
            "Nam: Đang soạn tin"
        )
        XCTAssertEqual(
            MessagingTypingCopy.stripTrailingEllipsis("Composing…"),
            "Composing"
        )
    }
}
