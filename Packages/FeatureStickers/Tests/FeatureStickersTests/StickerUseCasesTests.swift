import XCTest
import SplickDomain
@testable import FeatureStickers

final class MockFavoriteStickerRepository: FavoriteStickerRepositoryProtocol, @unchecked Sendable {
    var favorites: [Sticker] = []
    var lastAddedProvider: String?
    var lastAddedExternalId: String?
    var lastRemovedId: UUID?

    func fetchFavorites() async throws -> [Sticker] {
        favorites
    }

    func addFavorite(
        provider: String,
        externalId: String,
        url: URL,
        previewURL: URL?,
        name: String?,
        width: Int?,
        height: Int?
    ) async throws -> Sticker {
        lastAddedProvider = provider
        lastAddedExternalId = externalId
        let sticker = Sticker(
            id: externalId,
            url: url,
            previewURL: previewURL,
            source: provider == "klipy" ? .klipy : .custom(groupId: UUID()),
            width: width,
            height: height
        )
        favorites.append(sticker)
        return sticker
    }

    func removeFavorite(id: UUID) async throws {
        lastRemovedId = id
        favorites.removeAll { $0.id == id.uuidString }
    }
}

final class MockCustomEmojiRepository: CustomEmojiRepositoryProtocol, @unchecked Sendable {
    var emojis: [CustomEmoji] = []
    var lastAddedAlias: String?
    var lastAddedMediaId: UUID?
    var lastDeletedId: UUID?

    func fetchAllEmojis() async throws -> [CustomEmoji] {
        emojis
    }

    func fetchMyEmojis() async throws -> [CustomEmoji] {
        emojis
    }

    func addEmoji(alias: String?, mediaId: UUID) async throws -> CustomEmoji {
        lastAddedAlias = alias
        lastAddedMediaId = mediaId
        let emoji = CustomEmoji(
            id: UUID(),
            ownerId: UUID(),
            shortcode: alias ?? "custom",
            mediaUrl: URL(string: "https://cdn.splick.com/emoji.png")!,
            createdAt: Date()
        )
        emojis.append(emoji)
        return emoji
    }

    func deleteEmoji(emojiId: UUID) async throws {
        lastDeletedId = emojiId
        emojis.removeAll { $0.id == emojiId }
    }
}

final class MockKlipyMetaRepository: KlipyMetaRepositoryProtocol, @unchecked Sendable {
    var categories: [StickerCategory] = []
    var trendingTerms: [String] = []
    var lastRegisteredShareGifId: String?
    var lastRegisteredSearchQuery: String?

    func fetchCategories() async throws -> [StickerCategory] {
        categories
    }

    func fetchAutocomplete(query: String) async throws -> [String] {
        ["\(query)1", "\(query)2"]
    }

    func fetchSearchSuggestions(query: String) async throws -> [String] {
        ["\(query) suggestion"]
    }

    func fetchTrendingTerms() async throws -> [String] {
        trendingTerms
    }

    func registerShare(gifId: String, searchQuery: String?) async throws {
        lastRegisteredShareGifId = gifId
        lastRegisteredSearchQuery = searchQuery
    }
}

final class StickerUseCasesTests: XCTestCase {
    func testFavoriteStickerUseCases() async throws {
        let repo = MockFavoriteStickerRepository()
        let fetchUseCase = FetchFavoriteStickersUseCase(repository: repo)
        let addUseCase = AddFavoriteStickerUseCase(repository: repo)
        let removeUseCase = RemoveFavoriteStickerUseCase(repository: repo)

        // Initially empty
        let initial = try await fetchUseCase.execute()
        XCTAssertTrue(initial.isEmpty)

        // Add Klipy sticker
        let klipySticker = Sticker(
            id: "klipy-cat",
            url: URL(string: "https://static.klipy.com/cat.gif")!,
            source: .klipy,
            width: 200,
            height: 200
        )
        let addedKlipy = try await addUseCase.execute(sticker: klipySticker, name: "Cat")
        XCTAssertEqual(repo.lastAddedProvider, "klipy")
        XCTAssertEqual(repo.lastAddedExternalId, "klipy-cat")
        XCTAssertEqual(addedKlipy.id, "klipy-cat")

        // Add Custom sticker
        let groupId = UUID()
        let customSticker = Sticker(
            id: "custom-dog",
            url: URL(string: "https://cdn.splick.com/dog.png")!,
            source: .custom(groupId: groupId)
        )
        _ = try await addUseCase.execute(sticker: customSticker, name: "Dog")
        XCTAssertEqual(repo.lastAddedProvider, "custom")

        // Check favorites count
        let favorites = try await fetchUseCase.execute()
        XCTAssertEqual(favorites.count, 2)

        // Remove favorite
        let removeId = UUID()
        try await removeUseCase.execute(favoriteId: removeId)
        XCTAssertEqual(repo.lastRemovedId, removeId)
    }

    func testCustomEmojiUseCases() async throws {
        let repo = MockCustomEmojiRepository()
        let addUseCase = AddUserCustomEmojiUseCase(repository: repo)
        let fetchAllUseCase = FetchAllCustomEmojisUseCase(repository: repo)

        let mediaId = UUID()
        let emoji = try await addUseCase.execute(alias: "rocket", mediaId: mediaId)
        XCTAssertEqual(repo.lastAddedAlias, "rocket")
        XCTAssertEqual(repo.lastAddedMediaId, mediaId)
        XCTAssertEqual(emoji.shortcode, "rocket")

        let allEmojis = try await fetchAllUseCase.execute()
        XCTAssertEqual(allEmojis.count, 1)
    }

    func testKlipyMetaUseCases() async throws {
        let repo = MockKlipyMetaRepository()
        repo.categories = [
            StickerCategory(id: "trending", name: "Trending", previewURL: nil),
        ]
        repo.trendingTerms = ["love", "happy", "dance"]

        let fetchCategoriesUseCase = FetchStickerCategoriesUseCase(repository: repo)
        let categories = try await fetchCategoriesUseCase.execute()
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories.first?.name, "Trending")

        let fetchTrendingUseCase = FetchTrendingTermsUseCase(repository: repo)
        let trending = try await fetchTrendingUseCase.execute()
        XCTAssertEqual(trending, ["love", "happy", "dance"])

        let shareUseCase = RegisterStickerShareUseCase(repository: repo)
        await shareUseCase.execute(gifId: "gif-999", searchQuery: "cat dance")
        XCTAssertEqual(repo.lastRegisteredShareGifId, "gif-999")
        XCTAssertEqual(repo.lastRegisteredSearchQuery, "cat dance")
    }
}

final class CustomEmojiValidatorAndCategoryTests: XCTestCase {
    func testShortcodeValidator() {
        // Valid shortcodes
        XCTAssertTrue(CustomEmojiShortcodeValidator.isValid("fire"))
        XCTAssertTrue(CustomEmojiShortcodeValidator.isValid(":party_popper:"))
        XCTAssertTrue(CustomEmojiShortcodeValidator.isValid("cool_cat_123"))

        // Invalid shortcodes
        XCTAssertFalse(CustomEmojiShortcodeValidator.isValid("INVALID-WITH-DASHES"))
        XCTAssertFalse(CustomEmojiShortcodeValidator.isValid("has spaces"))
        XCTAssertFalse(CustomEmojiShortcodeValidator.isValid(""))
        XCTAssertFalse(CustomEmojiShortcodeValidator.isValid(String(repeating: "a", count: 35)))

        // Normalization
        XCTAssertEqual(CustomEmojiShortcodeValidator.normalize(":heart:"), "heart")
        XCTAssertEqual(CustomEmojiShortcodeValidator.normalize("  star  "), "star")
    }

    func testAttachmentPickerCategoryIdentifiable() {
        XCTAssertEqual(AttachmentPickerCategory.search.id, "search")
        XCTAssertEqual(AttachmentPickerCategory.favorites.id, "favorites")
        XCTAssertEqual(AttachmentPickerCategory.trending.id, "trending")
        XCTAssertEqual(AttachmentPickerCategory.emoji.id, "emoji")
        XCTAssertEqual(AttachmentPickerCategory.customPack.id, "custom")

        let cat = StickerCategory(id: "cats", name: "Cats", previewURL: nil)
        XCTAssertEqual(AttachmentPickerCategory.klipyPack(cat).id, "klipy-cats")

        let options = AttachmentPickerOptions(allowsGifSelection: false)
        XCTAssertFalse(options.allowsGifSelection)
    }
}
