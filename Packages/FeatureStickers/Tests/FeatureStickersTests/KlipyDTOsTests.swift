import XCTest
@testable import FeatureStickers

final class KlipyDTOsTests: XCTestCase {
    func testSearchResponseDecodesTenorStyleResultsAndNumericIds() throws {
        let json = """
        {
          "locale": "en_US",
          "next": "Mg==",
          "results": [
            {
              "id": "7362725012122549",
              "media_formats": {
                "gif": {
                  "url": "https://static.klipy.com/a.gif",
                  "duration": 0,
                  "preview": "",
                  "dims": [480, 434],
                  "size": 12
                },
                "tinygif": {
                  "url": "https://static.klipy.com/t.gif",
                  "dims": [220, 199]
                }
              }
            },
            {
              "id": 42,
              "files": {
                "mediumgif": { "url": "https://static.klipy.com/m.gif", "dims": [100, 80] }
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(KlipySearchResponseDTO.self, from: json)

        XCTAssertEqual(payload.next, "Mg==")
        XCTAssertEqual(payload.results.count, 2)
        XCTAssertEqual(payload.results[0].id, "7362725012122549")
        XCTAssertEqual(payload.results[0].mediaFormats?.gif?.url, "https://static.klipy.com/a.gif")
        XCTAssertEqual(payload.results[1].id, "42")
        XCTAssertEqual(payload.results[1].mediaFormats?.mediumGif?.url, "https://static.klipy.com/m.gif")

        XCTAssertNotNil(StickerMapper.toSticker(payload.results[0]))
        XCTAssertNotNil(StickerMapper.toSticker(payload.results[1]))
    }
}
