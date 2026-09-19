import XCTest
@testable import FeatureMedia

final class BoomerangTimelineTests: XCTestCase {
    func testPingPongOmitsDuplicatedEndpoints() {
        XCTAssertEqual(BoomerangTimeline.pingPongIndices(frameCount: 0), [])
        XCTAssertEqual(BoomerangTimeline.pingPongIndices(frameCount: 1), [0])
        XCTAssertEqual(BoomerangTimeline.pingPongIndices(frameCount: 2), [0, 1])
        XCTAssertEqual(BoomerangTimeline.pingPongIndices(frameCount: 3), [0, 1, 2, 1])
        XCTAssertEqual(BoomerangTimeline.pingPongIndices(frameCount: 4), [0, 1, 2, 3, 2, 1])
    }

    func testEvenPixelRoundsDownToEven() {
        XCTAssertEqual(BoomerangClipComposer.evenPixel(719), 718)
        XCTAssertEqual(BoomerangClipComposer.evenPixel(720), 720)
        XCTAssertEqual(BoomerangClipComposer.evenPixel(1), 2)
    }
}
