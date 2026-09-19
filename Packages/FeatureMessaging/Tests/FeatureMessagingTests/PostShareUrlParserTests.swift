import XCTest
@testable import FeatureMessaging

final class PostShareUrlParserTests: XCTestCase {
    private let postId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private var shareURL: String { "https://splick.app/post/\(postId.uuidString)" }

    func testUrlOnly() {
        let payload = PostShareUrlParser.parse(shareURL)
        XCTAssertEqual(payload?.postId, postId)
        XCTAssertNil(payload?.note)
        XCTAssertEqual(payload?.shareURL, shareURL)
    }

    func testNoteAndUrl() {
        let payload = PostShareUrlParser.parse("Check this\n\(shareURL)")
        XCTAssertEqual(payload?.postId, postId)
        XCTAssertEqual(payload?.note, "Check this")
    }

    func testSchemeUrl() {
        let payload = PostShareUrlParser.parse("splick://post/\(postId.uuidString)")
        XCTAssertEqual(payload?.postId, postId)
        XCTAssertNil(payload?.note)
    }

    func testUnrelatedLinkReturnsNil() {
        XCTAssertNil(PostShareUrlParser.parse("https://example.com/post/\(postId.uuidString)"))
    }
}
