import XCTest
@testable import Common

final class GifKeywordDetectorTests: XCTestCase {
    func testLastWord() {
        XCTAssertEqual(GifKeywordDetector.keyword(in: "that cat"), "cat")
        XCTAssertEqual(GifKeywordDetector.keyword(in: "happy"), "happy")
        XCTAssertEqual(GifKeywordDetector.keyword(in: "xin chào"), "chào")
    }

    func testMentionTokenIsIgnored() {
        XCTAssertNil(GifKeywordDetector.keyword(in: "hello @ja"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "@cat"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "hey @minh", mentionActive: true))
        XCTAssertEqual(GifKeywordDetector.keyword(in: "party time"), "time")
    }

    func testStopwords() {
        XCTAssertNil(GifKeywordDetector.keyword(in: "the"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "hello và"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "tôi"))
    }

    func testPunctuationAndSingleCharacter() {
        XCTAssertEqual(GifKeywordDetector.keyword(in: "wow!"), "wow")
        XCTAssertNil(GifKeywordDetector.keyword(in: "a"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "h"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "   "))
        XCTAssertNil(GifKeywordDetector.keyword(in: ""))
    }

    func testCursorUsesPrefixOnly() {
        XCTAssertEqual(GifKeywordDetector.keyword(in: "cat dog", cursor: 3), "cat")
        XCTAssertNil(GifKeywordDetector.keyword(in: "cat dog", cursor: 0))
    }
}
