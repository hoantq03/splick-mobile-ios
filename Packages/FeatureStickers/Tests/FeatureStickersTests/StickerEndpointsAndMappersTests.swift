import XCTest
import Networking
import SplickDomain
@testable import FeatureStickers

final class StickerEndpointsAndMappersTests: XCTestCase {
    func testCustomEmojiEndpoint() {
        let listAll = CustomEmojiEndpoint.listAll
        XCTAssertEqual(listAll.path, "/v1/social/emojis")
        XCTAssertEqual(listAll.method, .get)
        XCTAssertNil(listAll.body)

        let listMine = CustomEmojiEndpoint.listMine
        XCTAssertEqual(listMine.path, "/v1/social/users/me/emojis")
        XCTAssertEqual(listMine.method, .get)
        XCTAssertNil(listMine.body)

        let createReq = CreateCustomEmojiRequestDTO(alias: "party", mediaId: UUID())
        let create = CustomEmojiEndpoint.create(request: createReq)
        XCTAssertEqual(create.path, "/v1/social/users/me/emojis")
        XCTAssertEqual(create.method, .post)
        XCTAssertNotNil(create.body)

        let emojiId = UUID()
        let delete = CustomEmojiEndpoint.delete(emojiId: emojiId)
        XCTAssertEqual(delete.path, "/v1/social/emojis/\(emojiId)")
        XCTAssertEqual(delete.method, .delete)
        XCTAssertNil(delete.body)
    }

    func testStickerEndpoint() {
        let groupId = UUID()

        // Without keyword
        let epNoKw = StickerEndpoint.groupStickers(groupId: groupId, keyword: nil)
        XCTAssertEqual(epNoKw.path, "/v1/stickers/groups/\(groupId)")
        XCTAssertEqual(epNoKw.method, .get)
        XCTAssertNil(epNoKw.queryItems)

        // With empty keyword
        let epEmptyKw = StickerEndpoint.groupStickers(groupId: groupId, keyword: "")
        XCTAssertNil(epEmptyKw.queryItems)

        // With keyword
        let epKw = StickerEndpoint.groupStickers(groupId: groupId, keyword: "funny")
        XCTAssertEqual(epKw.queryItems?.count, 1)
        XCTAssertEqual(epKw.queryItems?.first?.name, "keyword")
        XCTAssertEqual(epKw.queryItems?.first?.value, "funny")
    }

    func testCustomEmojiMapper() {
        let emojiId = UUID()
        let ownerId = UUID()
        let now = Date()

        let validDTO = CustomEmojiResponseDTO(
            id: emojiId,
            ownerId: ownerId,
            shortcode: "cat_party",
            mediaUrl: "https://cdn.splick.com/emojis/cat.png",
            createdAt: now
        )

        let domain = CustomEmojiMapper.toDomain(validDTO)
        XCTAssertNotNil(domain)
        XCTAssertEqual(domain?.id, emojiId)
        XCTAssertEqual(domain?.ownerId, ownerId)
        XCTAssertEqual(domain?.shortcode, "cat_party")
        XCTAssertEqual(domain?.mediaUrl.absoluteString, "https://cdn.splick.com/emojis/cat.png")

        let invalidDTO = CustomEmojiResponseDTO(
            id: emojiId,
            ownerId: nil,
            shortcode: "broken",
            mediaUrl: "",
            createdAt: now
        )
        XCTAssertNil(CustomEmojiMapper.toDomain(invalidDTO))
    }

    func testStickerMapper() throws {
        // Klipy GIF mapping decoded from JSON
        let json = """
        {
            "id": "klipy-123",
            "media_formats": {
                "gif": {
                    "url": "https://static.klipy.com/test.gif",
                    "dims": [200, 200]
                },
                "tinygif": {
                    "url": "https://static.klipy.com/thumb.gif",
                    "dims": [100, 100]
                }
            }
        }
        """.data(using: .utf8)!

        let gifDTO = try JSONDecoder().decode(KlipyGifDTO.self, from: json)
        let sticker = StickerMapper.toSticker(gifDTO)
        XCTAssertNotNil(sticker)
        XCTAssertEqual(sticker?.id, "klipy-123")
        XCTAssertEqual(sticker?.url.absoluteString, "https://static.klipy.com/test.gif")
        XCTAssertEqual(sticker?.previewURL?.absoluteString, "https://static.klipy.com/thumb.gif")
        XCTAssertEqual(sticker?.source, .klipy)
        XCTAssertEqual(sticker?.width, 200)
        XCTAssertEqual(sticker?.height, 200)

        // Splick Sticker mapping
        let groupId = UUID()
        let splickDTO = SplickStickerDTO(
            id: "splick-custom-1",
            url: "https://cdn.splick.com/stickers/custom.png",
            previewUrl: "https://cdn.splick.com/stickers/custom_preview.png",
            width: 300,
            height: 300
        )
        let customSticker = StickerMapper.toSticker(splickDTO, groupId: groupId)
        XCTAssertNotNil(customSticker)
        XCTAssertEqual(customSticker?.id, "splick-custom-1")
        XCTAssertEqual(customSticker?.source, .custom(groupId: groupId))
        XCTAssertEqual(customSticker?.width, 300)
        XCTAssertEqual(customSticker?.height, 300)
    }

    func testKlipyMetaMapper() {
        let categoryDTO = KlipyCategoryDTO(
            searchterm: "reaction",
            name: "Reactions",
            image: "https://static.klipy.com/cat.jpg"
        )
        let category = KlipyMetaMapper.toCategory(categoryDTO)
        XCTAssertEqual(category.id, "reaction")
        XCTAssertEqual(category.name, "Reactions")
        XCTAssertEqual(category.previewURL?.absoluteString, "https://static.klipy.com/cat.jpg")
    }
}
