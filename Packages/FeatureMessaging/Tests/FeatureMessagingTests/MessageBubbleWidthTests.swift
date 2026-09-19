import XCTest
@testable import FeatureMessaging

final class MessageBubbleWidthTests: XCTestCase {
    func testNarrowPhoneDoesNotOverflowOppositeGutter() {
        let innerRow: CGFloat = 296
        let max = MessageThreadRowLayout.contentMaxWidth(forRowWidth: innerRow)
        XCTAssertLessThanOrEqual(max + MessageThreadRowLayout.rowSideSpacer, innerRow + 0.5)
        XCTAssertLessThan(max, 268)
    }

    func testTypicalPhoneUsesFraction() {
        let innerRow: CGFloat = 366
        let max = MessageThreadRowLayout.contentMaxWidth(forRowWidth: innerRow)
        XCTAssertEqual(max, innerRow * 0.72, accuracy: 0.5)
    }

    func testTabletIsCapped() {
        let max = MessageThreadRowLayout.contentMaxWidth(forRowWidth: 736)
        XCTAssertEqual(max, MessageThreadRowLayout.bubbleAbsoluteMaxWidth)
    }
}
