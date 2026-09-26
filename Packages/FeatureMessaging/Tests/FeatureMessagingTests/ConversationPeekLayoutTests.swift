import XCTest
@testable import FeatureMessaging

final class ConversationPeekLayoutTests: XCTestCase {
    func testPreviewCardFillsDownToMenuClearance() {
        let dest = ConversationPeekLayout.previewDestination(
            top: 80,
            bottom: 800,
            optionsHeight: 104,
            gap: 8
        )
        XCTAssertEqual(dest.minY, 192, accuracy: 0.5)
        XCTAssertEqual(dest.maxY, 800, accuracy: 0.5)
        XCTAssertEqual(dest.height, 608, accuracy: 0.5)
        XCTAssertGreaterThan(dest.height, ConversationPeekLayout.minPreviewHeight)
        XCTAssertGreaterThan(dest.minY, 80, "Band above the card must stay empty so dimmer taps can dismiss")
    }

    func testTinyRemainingSpaceUsesAllOfIt() {
        let dest = ConversationPeekLayout.previewDestination(
            top: 80,
            bottom: 280,
            optionsHeight: 104,
            gap: 8
        )
        XCTAssertEqual(dest.minY, 160, accuracy: 0.5)
        XCTAssertEqual(dest.maxY, 280, accuracy: 0.5)
    }
}
