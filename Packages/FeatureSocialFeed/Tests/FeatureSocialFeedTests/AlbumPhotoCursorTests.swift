import XCTest
@testable import FeatureSocialFeed

final class AlbumPhotoCursorTests: XCTestCase {

    func testEncodeAndDecodeCursor() {
        let now = Date()
        let id = UUID()

        let cursor = AlbumPhotoCursor.encode(createdAt: now, mediaItemId: id)
        XCTAssertFalse(cursor.isEmpty)

        let decoded = AlbumPhotoCursor.decode(cursor)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.mediaItemId, id)
        XCTAssertEqual(
            Int(decoded?.createdAt.timeIntervalSince1970 ?? 0),
            Int(now.timeIntervalSince1970)
        )
    }

    func testDecodeInvalidCursor() {
        XCTAssertNil(AlbumPhotoCursor.decode("invalid_base64_!@#"))
        XCTAssertNil(AlbumPhotoCursor.decode(""))
        // Base64 valid but missing separator or invalid UUID
        let encodedNoSep = Data("2026-09-20T00:00:00Z".utf8).base64EncodedString()
        XCTAssertNil(AlbumPhotoCursor.decode(encodedNoSep))

        let encodedInvalidUUID = Data("2026-09-20T00:00:00Z|not-a-uuid".utf8).base64EncodedString()
        XCTAssertNil(AlbumPhotoCursor.decode(encodedInvalidUUID))
    }
}
