import XCTest
@testable import FeatureMessaging

final class SharePostMessageComposerTests: XCTestCase {
    func testNoteEmptyUsesURLOnly() {
        let url = URL(string: "https://splick.app/post/abc")!
        XCTAssertEqual(SharePostMessageComposer.composeBody(note: "  ", shareURL: url), url.absoluteString)
    }

    func testNoteAndURLAreJoinedWithNewline() {
        let url = URL(string: "https://splick.app/post/abc")!
        XCTAssertEqual(
            SharePostMessageComposer.composeBody(note: "Check this out", shareURL: url),
            "Check this out\nhttps://splick.app/post/abc"
        )
    }

    func testNoteIsTruncatedSoURLFits() {
        let url = URL(string: "https://splick.app/post/abc")!
        let note = String(repeating: "x", count: SharePostMessageComposer.maxLength)
        let body = SharePostMessageComposer.composeBody(note: note, shareURL: url)
        XCTAssertLessThanOrEqual(body.utf16.count, SharePostMessageComposer.maxLength)
        XCTAssertTrue(body.hasSuffix(url.absoluteString))
        XCTAssertTrue(body.contains("\n"))
    }
}
