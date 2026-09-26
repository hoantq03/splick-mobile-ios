import XCTest
@testable import Common

final class GifKeywordDetectorTests: XCTestCase {
    func testExactlyTwoWords() {
        XCTAssertEqual(GifKeywordDetector.keyword(in: "that cat"), "cat")
        XCTAssertEqual(GifKeywordDetector.keyword(in: "xin chào"), "chào")
        XCTAssertEqual(GifKeywordDetector.keyword(in: "party time"), "time")
        XCTAssertNil(GifKeywordDetector.keyword(in: "happy"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "one two three"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "xin chào bạn nhé"))
    }

    func testMentionTokenIsIgnored() {
        XCTAssertNil(GifKeywordDetector.keyword(in: "hello @ja"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "@cat"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "hey @minh", mentionActive: true))
    }

    func testStopwords() {
        XCTAssertNil(GifKeywordDetector.keyword(in: "the"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "hello và"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "tôi"))
    }

    func testPunctuationAndSingleCharacter() {
        XCTAssertNil(GifKeywordDetector.keyword(in: "wow!"))
        XCTAssertEqual(GifKeywordDetector.keyword(in: "oh wow!"), "wow")
        XCTAssertNil(GifKeywordDetector.keyword(in: "a"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "h"))
        XCTAssertNil(GifKeywordDetector.keyword(in: "   "))
        XCTAssertNil(GifKeywordDetector.keyword(in: ""))
    }

    func testCursorUsesPrefixOnly() {
        XCTAssertNil(GifKeywordDetector.keyword(in: "cat dog", cursor: 3))
        XCTAssertEqual(GifKeywordDetector.keyword(in: "cat dog", cursor: 7), "dog")
        XCTAssertNil(GifKeywordDetector.keyword(in: "cat dog", cursor: 0))
    }
}
