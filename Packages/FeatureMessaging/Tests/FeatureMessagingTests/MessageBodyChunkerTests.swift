import XCTest
@testable import FeatureMessaging

final class MessageBodyChunkerTests: XCTestCase {
    func testShortBodyStaysSingleChunk() {
        XCTAssertEqual(MessageBodyChunker.chunk("hello"), ["hello"])
    }

    func testEmptyBodyYieldsNoChunks() {
        XCTAssertEqual(MessageBodyChunker.chunk(""), [])
        XCTAssertEqual(MessageBodyChunker.partsForSend(""), [""])
    }

    func testSplitsAtMaxLength() {
        let body = String(repeating: "a", count: MessageBodyChunker.maxLength + 50)
        let chunks = MessageBodyChunker.chunk(body)
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].utf16.count, MessageBodyChunker.maxLength)
        XCTAssertEqual(chunks[1].utf16.count, 50)
        XCTAssertEqual(chunks.joined(), body)
    }

    func testPrefersWhitespaceNearEndOfWindow() {
        let prefix = String(repeating: "x", count: MessageBodyChunker.maxLength - 10)
        let body = prefix + " hello world and more text after the break point here"
        let chunks = MessageBodyChunker.chunk(body)
        XCTAssertGreaterThanOrEqual(chunks.count, 2)
        XCTAssertTrue(chunks[0].hasSuffix(" "))
        XCTAssertEqual(chunks.joined(), body)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.utf16.count, MessageBodyChunker.maxLength)
        }
    }

    func testClampForEditTruncates() {
        let body = String(repeating: "b", count: MessageBodyChunker.maxLength + 3)
        XCTAssertEqual(MessageBodyChunker.clampForEdit(body).utf16.count, MessageBodyChunker.maxLength)
    }
}
