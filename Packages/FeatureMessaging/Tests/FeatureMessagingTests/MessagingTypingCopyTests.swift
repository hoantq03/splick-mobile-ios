import XCTest
@testable import FeatureMessaging

final class MessagingTypingCopyTests: XCTestCase {
    func test_directShowsTypingLabelOnly() {
        let peer = UUID()
        let state = MessagingTypingCopy.inboxTypingState(
            isGroup: false,
            userIds: [peer],
            typing: "Composing...",
            usernameForUserId: { _ in "nam_user" }
        )
        XCTAssertEqual(state?.layout, .direct)
        XCTAssertEqual(state?.typingBase, "Composing")
    }

    func test_groupShowsUsernameLayout() {
        let first = UUID()
        let state = MessagingTypingCopy.inboxTypingState(
            isGroup: true,
            userIds: [first],
            typing: "Composing...",
            usernameForUserId: { _ in "nam_user" }
        )
        guard case .group(let username, _) = state?.layout else {
            return XCTFail("Expected group layout")
        }
        XCTAssertEqual(username, "nam_user")
        XCTAssertEqual(state?.typingBase, "Composing")
    }

    func test_groupFallsBackToDirectWhenUsernameMissing() {
        let first = UUID()
        let state = MessagingTypingCopy.inboxTypingState(
            isGroup: true,
            userIds: [first],
            typing: "Composing...",
            usernameForUserId: { _ in nil }
        )
        XCTAssertEqual(state?.layout, .direct)
    }

    func test_givenName_prefersLastToken() {
        XCTAssertEqual(MessagingTypingCopy.givenName(from: "Nguyen Van Nam"), "Nam")
        XCTAssertEqual(MessagingTypingCopy.givenName(from: "nam_user"), "nam_user")
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
