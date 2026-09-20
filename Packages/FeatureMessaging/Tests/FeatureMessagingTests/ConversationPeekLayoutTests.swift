import XCTest
@testable import FeatureMessaging

final class ConversationPeekLayoutTests: XCTestCase {
    func testPreviewCardDoesNotFillRemainingScreen() {
        let dest = ConversationPeekLayout.previewDestination(
            top: 80,
            bottom: 800,
            optionsHeight: 104,
            gap: 8
        )
        XCTAssertEqual(dest.minY, 192, accuracy: 0.5)
        XCTAssertLessThan(dest.maxY, 800)
        XCTAssertEqual(
            dest.height,
            (800 - 80) * ConversationPeekLayout.previewMaxUsableFraction,
            accuracy: 0.5
        )
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
