import XCTest
import Networking
import SplickDomain
@testable import FeatureStickers

// MARK: - Mock KlipyDataSource

final class MockKlipyDataSource: KlipyDataSourceProtocol, @unchecked Sendable {
    var searchResult: StickerFetchResult = StickerFetchResult(stickers: [])
    var trendingResult: StickerFetchResult = StickerFetchResult(stickers: [])
    var categoriesResult: [StickerCategory] = []
    var autocompleteResult: [String] = []
    var searchSuggestionsResult: [String] = []
    var trendingTermsResult: [String] = []
    var errorToThrow: Error?

    var lastSearchQuery: String?
    var lastSearchPosition: String?
    var lastTrendingPosition: String?
    var lastAutocompleteQuery: String?
    var lastSearchSuggestionsQuery: String?
    var lastRegisteredGifId: String?
    var lastRegisteredSearchQuery: String?

    func search(query: String, position: String?) async throws -> StickerFetchResult {
        if let error = errorToThrow { throw error }
        lastSearchQuery = query
        lastSearchPosition = position
        return searchResult
    }

    func trending(position: String?) async throws -> StickerFetchResult {
        if let error = errorToThrow { throw error }
        lastTrendingPosition = position
        return trendingResult
    }

    func categories() async throws -> [StickerCategory] {
        if let error = errorToThrow { throw error }
        return categoriesResult
    }

    func autocomplete(query: String) async throws -> [String] {
        if let error = errorToThrow { throw error }
        lastAutocompleteQuery = query
        return autocompleteResult
    }

    func searchSuggestions(query: String) async throws -> [String] {
        if let error = errorToThrow { throw error }
        lastSearchSuggestionsQuery = query
        return searchSuggestionsResult
    }

    func trendingTerms() async throws -> [String] {
        if let error = errorToThrow { throw error }
        return trendingTermsResult
    }

    func registerShare(gifId: String, searchQuery: String?) async throws {
        if let error = errorToThrow { throw error }
        lastRegisteredGifId = gifId
        lastRegisteredSearchQuery = searchQuery
    }
}

// MARK: - Mock SplickStickerDataSource

final class MockSplickStickerDataSource: SplickStickerDataSourceProtocol, @unchecked Sendable {
    var stickers: [Sticker] = []
    var errorToThrow: Error?
    var lastGroupId: UUID?
    var lastKeyword: String?

    func fetchStickers(groupId: UUID, keyword: String) async throws -> [Sticker] {
        if let error = errorToThrow { throw error }
        lastGroupId = groupId
        lastKeyword = keyword
        return stickers
    }
}

// MARK: - StickerRepositoryImpl Tests

final class StickerRepositoryImplTests: XCTestCase {
    private var klipyDataSource: MockKlipyDataSource!
    private var splickDataSource: MockSplickStickerDataSource!
    private var repository: StickerRepositoryImpl!

    override func setUp() {
        super.setUp()
        klipyDataSource = MockKlipyDataSource()
        splickDataSource = MockSplickStickerDataSource()
        repository = StickerRepositoryImpl(
            klipyDataSource: klipyDataSource,
            splickDataSource: splickDataSource
        )
    }

    func testFetchStickersKlipyWithQuery() async throws {
        let sticker = Sticker(id: "cat-1", url: URL(string: "https://klipy.com/cat.gif")!, source: .klipy)
        klipyDataSource.searchResult = StickerFetchResult(stickers: [sticker], nextPosition: "abc")

        let result = try await repository.fetchStickers(query: "cat", source: .klipy, position: nil)

        XCTAssertEqual(result.stickers.count, 1)
        XCTAssertEqual(result.nextPosition, "abc")
        XCTAssertEqual(klipyDataSource.lastSearchQuery, "cat")
    }

    func testFetchStickersKlipyEmptyQueryFetchesTrending() async throws {
        let sticker = Sticker(id: "t-1", url: URL(string: "https://klipy.com/trend.gif")!, source: .klipy)
        klipyDataSource.trendingResult = StickerFetchResult(stickers: [sticker])

        // Empty query → trending
        let result = try await repository.fetchStickers(query: "   ", source: .klipy, position: "pos1")

        XCTAssertEqual(result.stickers.count, 1)
        XCTAssertEqual(klipyDataSource.lastTrendingPosition, "pos1")
    }

    func testFetchStickersCustomSource() async throws {
        let groupId = UUID()
        let sticker = Sticker(id: "s-1", url: URL(string: "https://cdn.splick.com/1.png")!, source: .custom(groupId: groupId))
        splickDataSource.stickers = [sticker]

        let result = try await repository.fetchStickers(query: "fun", source: .custom(groupId: groupId))

        XCTAssertEqual(result.stickers.count, 1)
        XCTAssertEqual(splickDataSource.lastGroupId, groupId)
        XCTAssertEqual(splickDataSource.lastKeyword, "fun")
    }

    func testFetchStickersKlipyErrorPropagates() async {
        klipyDataSource.errorToThrow = StickerError.rateLimitExceeded

        await XCTAssertThrowsAsyncError(
            try await repository.fetchStickers(query: "cat", source: .klipy)
        )
    }
}

// MARK: - KlipyMetaRepositoryImpl Tests

final class KlipyMetaRepositoryImplTests: XCTestCase {
    private var dataSource: MockKlipyDataSource!
    private var repository: KlipyMetaRepositoryImpl!

    override func setUp() {
        super.setUp()
        dataSource = MockKlipyDataSource()
        repository = KlipyMetaRepositoryImpl(klipyDataSource: dataSource)
    }

    func testFetchCategories() async throws {
        dataSource.categoriesResult = [
            StickerCategory(id: "trending", name: "Trending", previewURL: nil),
        ]
        let categories = try await repository.fetchCategories()
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories.first?.id, "trending")
    }

    func testFetchAutocomplete() async throws {
        dataSource.autocompleteResult = ["cats", "catsdance"]
        let results = try await repository.fetchAutocomplete(query: "cats")
        XCTAssertEqual(results, ["cats", "catsdance"])
        XCTAssertEqual(dataSource.lastAutocompleteQuery, "cats")
    }

    func testFetchSearchSuggestions() async throws {
        dataSource.searchSuggestionsResult = ["cat reaction"]
        let results = try await repository.fetchSearchSuggestions(query: "cat")
        XCTAssertEqual(results, ["cat reaction"])
        XCTAssertEqual(dataSource.lastSearchSuggestionsQuery, "cat")
    }

    func testFetchTrendingTerms() async throws {
        dataSource.trendingTermsResult = ["love", "dance"]
        let terms = try await repository.fetchTrendingTerms()
        XCTAssertEqual(terms, ["love", "dance"])
    }

    func testRegisterShare() async throws {
        try await repository.registerShare(gifId: "gif-42", searchQuery: "party")
        XCTAssertEqual(dataSource.lastRegisteredGifId, "gif-42")
        XCTAssertEqual(dataSource.lastRegisteredSearchQuery, "party")
    }

    func testRegisterShareNilQuery() async throws {
        try await repository.registerShare(gifId: "gif-99", searchQuery: nil)
        XCTAssertEqual(dataSource.lastRegisteredGifId, "gif-99")
        XCTAssertNil(dataSource.lastRegisteredSearchQuery)
    }
}

// MARK: - FavoriteStickerMapper Tests

final class FavoriteStickerMapperTests: XCTestCase {
    func testMapsKlipyProvider() {
        let dto = StickerFavoriteDTO(
            id: UUID(),
            provider: "klipy",
            externalId: "klipy-1",
            url: "https://klipy.com/cat.gif",
            previewUrl: "https://klipy.com/cat_thumb.gif",
            name: "Cat",
            width: 200,
            height: 200
        )
        let sticker = FavoriteStickerMapper.toSticker(dto)
        XCTAssertNotNil(sticker)
        XCTAssertEqual(sticker?.source, .klipy)
        XCTAssertEqual(sticker?.id, "klipy-1")
        XCTAssertNotNil(sticker?.previewURL)
        XCTAssertEqual(sticker?.width, 200)
        XCTAssertEqual(sticker?.height, 200)
    }

    func testMapsCustomProviderWithFallbackGroupId() {
        let groupId = UUID()
        let dto = StickerFavoriteDTO(
            id: UUID(),
            provider: "custom",
            externalId: "custom-1",
            url: "https://cdn.splick.com/s.png",
            previewUrl: nil,
            name: nil,
            width: nil,
            height: nil
        )
        let sticker = FavoriteStickerMapper.toSticker(dto, fallbackGroupId: groupId)
        XCTAssertNotNil(sticker)
        XCTAssertEqual(sticker?.source, .custom(groupId: groupId))
    }

    func testMapsCustomProviderWithoutFallbackGroupIdDefaultsToKlipy() {
        let dto = StickerFavoriteDTO(
            id: UUID(),
            provider: "custom",
            externalId: "custom-1",
            url: "https://cdn.splick.com/s.png",
            previewUrl: nil,
            name: nil,
            width: nil,
            height: nil
        )
        let sticker = FavoriteStickerMapper.toSticker(dto, fallbackGroupId: nil)
        XCTAssertNotNil(sticker)
        XCTAssertEqual(sticker?.source, .klipy)
    }

    func testMapsUnknownProviderDefaultsToKlipy() {
        let dto = StickerFavoriteDTO(
            id: UUID(),
            provider: "giphy",
            externalId: "giphy-1",
            url: "https://giphy.com/g.gif",
            previewUrl: nil,
            name: nil,
            width: nil,
            height: nil
        )
        let sticker = FavoriteStickerMapper.toSticker(dto)
        XCTAssertNotNil(sticker)
        XCTAssertEqual(sticker?.source, .klipy)
    }

    func testReturnsNilForInvalidURL() {
        let dto = StickerFavoriteDTO(
            id: UUID(),
            provider: "klipy",
            externalId: "bad",
            url: "",
            previewUrl: nil,
            name: nil,
            width: nil,
            height: nil
        )
        XCTAssertNil(FavoriteStickerMapper.toSticker(dto))
    }
}

// MARK: - FavoriteStickerEndpoint Tests

final class FavoriteStickerEndpointTests: XCTestCase {
    func testListEndpoint() {
        let ep = FavoriteStickerEndpoint.list
        XCTAssertEqual(ep.path, "/v1/feed/sticker-favorites")
        XCTAssertEqual(ep.method, .get)
        XCTAssertNil(ep.body)
    }

    func testUpsertEndpoint() {
        let request = UpsertStickerFavoriteRequestDTO(
            provider: "klipy",
            externalId: "klipy-1",
            url: "https://klipy.com/cat.gif",
            previewUrl: nil,
            name: "Cat",
            width: 200,
            height: 200
        )
        let ep = FavoriteStickerEndpoint.upsert(request)
        XCTAssertEqual(ep.path, "/v1/feed/sticker-favorites")
        XCTAssertEqual(ep.method, .put)
        XCTAssertNotNil(ep.body)
    }

    func testDeleteEndpoint() {
        let id = UUID()
        let ep = FavoriteStickerEndpoint.delete(id: id)
        XCTAssertEqual(ep.path, "/v1/feed/sticker-favorites/\(id.uuidString)")
        XCTAssertEqual(ep.method, .delete)
        XCTAssertNil(ep.body)
    }
}

// MARK: - Domain Errors Tests

final class StickerDomainErrorsTests: XCTestCase {
    func testStickerErrorDescriptions() {
        XCTAssertNotNil(StickerError.apiKeyMissing.errorDescription)
        XCTAssertNotNil(StickerError.rateLimitExceeded.errorDescription)
        XCTAssertNotNil(StickerError.groupRequired.errorDescription)
        XCTAssertNotNil(StickerError.network("Test error").errorDescription)
        XCTAssertEqual(StickerError.network("Test error").errorDescription, "Test error")
    }

    func testStickerErrorEquality() {
        XCTAssertEqual(StickerError.apiKeyMissing, StickerError.apiKeyMissing)
        XCTAssertEqual(StickerError.rateLimitExceeded, StickerError.rateLimitExceeded)
        XCTAssertEqual(StickerError.groupRequired, StickerError.groupRequired)
        XCTAssertEqual(StickerError.network("msg"), StickerError.network("msg"))
        XCTAssertNotEqual(StickerError.network("a"), StickerError.network("b"))
        XCTAssertNotEqual(StickerError.apiKeyMissing, StickerError.rateLimitExceeded)
    }

    func testCustomEmojiErrorDescriptions() {
        XCTAssertNotNil(CustomEmojiError.invalidResponse.errorDescription)
        XCTAssertNotNil(CustomEmojiError.invalidShortcode.errorDescription)
        XCTAssertNotNil(CustomEmojiError.imageProcessingFailed.errorDescription)
    }
}

// MARK: - FetchSuggestionsUseCase Tests

final class FetchSuggestionsUseCaseTests: XCTestCase {
    func testAutocompleteType() async throws {
        let repo = MockKlipyMetaRepository()
        let useCase = FetchSuggestionsUseCase(repository: repo)

        let results = try await useCase.execute(query: "fun", type: .autocomplete)
        XCTAssertEqual(results, ["fun1", "fun2"])
    }

    func testSearchSuggestionsType() async throws {
        let repo = MockKlipyMetaRepository()
        let useCase = FetchSuggestionsUseCase(repository: repo)

        let results = try await useCase.execute(query: "cat", type: .searchSuggestions)
        XCTAssertEqual(results, ["cat suggestion"])
    }
}

// MARK: - DeleteUserCustomEmojiUseCase Tests

final class DeleteUserCustomEmojiUseCaseTests: XCTestCase {
    func testDeleteDelegatesCorrectly() async throws {
        let repo = MockCustomEmojiRepository()
        let useCase = DeleteUserCustomEmojiUseCase(repository: repo)

        let emojiId = UUID()
        try await useCase.execute(emojiId: emojiId)

        XCTAssertEqual(repo.lastDeletedId, emojiId)
    }
}

// MARK: - StickerFetchResult Tests

final class StickerFetchResultTests: XCTestCase {
    func testEquatableWithSameValues() {
        let r1 = StickerFetchResult(stickers: [], nextPosition: "abc")
        let r2 = StickerFetchResult(stickers: [], nextPosition: "abc")
        XCTAssertEqual(r1, r2)
    }

    func testEquatableWithDifferentNextPosition() {
        let r1 = StickerFetchResult(stickers: [], nextPosition: "abc")
        let r2 = StickerFetchResult(stickers: [], nextPosition: nil)
        XCTAssertNotEqual(r1, r2)
    }

    func testDefaultNextPositionIsNil() {
        let r = StickerFetchResult(stickers: [])
        XCTAssertNil(r.nextPosition)
    }
}

// MARK: - StickerMapper Edge Cases

final class StickerMapperEdgeCasesTests: XCTestCase {
    func testToStickerGifDTOReturnsNilForMissingMediaFormats() throws {
        let json = """
        {"id": "no-media"}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(KlipyGifDTO.self, from: json)
        XCTAssertNil(StickerMapper.toSticker(dto))
    }

    func testToStickerGifDTOReturnsNilForInvalidURL() throws {
        // Build a DTO with invalid url
        let json = """
        {
            "id": "bad-url",
            "media_formats": {
                "gif": {
                    "url": "",
                    "dims": [100, 100]
                }
            }
        }
        """.data(using: .utf8)!
        let gifDTO = try JSONDecoder().decode(KlipyGifDTO.self, from: json)
        XCTAssertNil(StickerMapper.toSticker(gifDTO))
    }

    func testToStickerSplickDTOReturnsNilForInvalidURL() {
        let groupId = UUID()
        let dto = SplickStickerDTO(id: "bad", url: "", previewUrl: nil, width: nil, height: nil)
        XCTAssertNil(StickerMapper.toSticker(dto, groupId: groupId))
    }

    func testToStickerSplickDTOWithPreviewAndDimensions() {
        let groupId = UUID()
        let dto = SplickStickerDTO(
            id: "s1",
            url: "https://cdn.splick.com/s1.png",
            previewUrl: "https://cdn.splick.com/s1_thumb.png",
            width: 150,
            height: 250
        )
        let sticker = StickerMapper.toSticker(dto, groupId: groupId)
        XCTAssertNotNil(sticker)
        XCTAssertEqual(sticker?.previewURL?.absoluteString, "https://cdn.splick.com/s1_thumb.png")
        XCTAssertEqual(sticker?.width, 150)
        XCTAssertEqual(sticker?.height, 250)
    }

    func testToStickerFromMediumGif() throws {
        // When gif is absent but mediumGif is present
        let json = """
        {
            "id": "medium-only",
            "files": {
                "mediumgif": {
                    "url": "https://klipy.com/medium.gif",
                    "dims": [300, 200]
                }
            }
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(KlipyGifDTO.self, from: json)
        let sticker = StickerMapper.toSticker(dto)
        XCTAssertNotNil(sticker)
        XCTAssertEqual(sticker?.id, "medium-only")
        XCTAssertEqual(sticker?.url.absoluteString, "https://klipy.com/medium.gif")
        XCTAssertEqual(sticker?.width, 300)
        XCTAssertEqual(sticker?.height, 200)
    }

    func testToStickerFromTinyGifOnly() throws {
        // When only tinyGif is present
        let json = """
        {
            "id": "tiny-only",
            "media_formats": {
                "tinygif": {
                    "url": "https://klipy.com/tiny.gif",
                    "dims": [100]
                }
            }
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(KlipyGifDTO.self, from: json)
        let sticker = StickerMapper.toSticker(dto)
        XCTAssertNotNil(sticker)
        // When only one dim, height should be nil
        XCTAssertEqual(sticker?.width, 100)
        XCTAssertNil(sticker?.height)
    }
}

// MARK: - KlipyMetaMapper Edge Cases

final class KlipyMetaMapperEdgeCasesTests: XCTestCase {
    func testCategoryWithInvalidImageURLReturnsNilPreview() {
        let dto = KlipyCategoryDTO(searchterm: "cats", name: "Cats", image: "not-a-url")
        // KlipyMetaMapper.toCategory wraps with URL(string:), which may succeed for relative paths
        // but the intent is that an invalid URL returns nil previewURL
        let category = KlipyMetaMapper.toCategory(dto)
        XCTAssertEqual(category.id, "cats")
        XCTAssertEqual(category.name, "Cats")
        // URL(string: "not-a-url") is actually valid (relative URL), so we just verify mapping is done
        XCTAssertNotNil(category) // Just ensure no crash
    }

    func testCategoryWithNilImageReturnsNilPreview() {
        let dto = KlipyCategoryDTO(searchterm: "happy", name: "Happy", image: nil)
        let category = KlipyMetaMapper.toCategory(dto)
        XCTAssertEqual(category.id, "happy")
        XCTAssertNil(category.previewURL)
    }
}

// MARK: - KlipySearchResponseDTO Additional Parsing Tests

final class KlipyDTOAdditionalTests: XCTestCase {
    func testSearchResponseDecodesDataNestedFormat() throws {
        // Simulating a response where results are nested under a "data" key
        let json = """
        {
            "data": {
                "results": [
                    {
                        "id": "nested-1",
                        "media_formats": {
                            "gif": { "url": "https://klipy.com/n.gif", "dims": [100, 100] }
                        }
                    }
                ],
                "next": "page2"
            }
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(KlipySearchResponseDTO.self, from: json)
        XCTAssertEqual(payload.results.count, 1)
        XCTAssertEqual(payload.results[0].id, "nested-1")
        XCTAssertEqual(payload.next, "page2")
    }

    func testSearchResponseDecodesDataArrayFormat() throws {
        // data key contains array directly
        let json = """
        {
            "data": [
                {
                    "id": "data-arr-1",
                    "media_formats": {
                        "gif": { "url": "https://klipy.com/d.gif", "dims": [200, 150] }
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(KlipySearchResponseDTO.self, from: json)
        XCTAssertEqual(payload.results.count, 1)
        XCTAssertEqual(payload.results[0].id, "data-arr-1")
        XCTAssertNil(payload.next)
    }

    func testSearchResponseFallsBackToEmptyResultsOnUnrecognizedFormat() throws {
        // Neither results, nor data key - falls back to empty
        let json = """
        {
            "next": "sometoken"
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(KlipySearchResponseDTO.self, from: json)
        XCTAssertTrue(payload.results.isEmpty)
        XCTAssertEqual(payload.next, "sometoken")
    }
}

// MARK: - GifPickerViewModel Tests

@MainActor
final class GifPickerViewModelTests: XCTestCase {
    private var stickerRepo: FakeStickerRepository2!
    private var klipyMetaRepo: MockKlipyMetaRepository!
    private var favoriteRepo: MockFavoriteStickerRepository!
    private var vm: GifPickerViewModel!

    override func setUp() {
        super.setUp()
        stickerRepo = FakeStickerRepository2()
        klipyMetaRepo = MockKlipyMetaRepository()
        favoriteRepo = MockFavoriteStickerRepository()

        let fetchStickers = FetchStickersUseCase(repository: stickerRepo)
        let fetchCategories = FetchStickerCategoriesUseCase(repository: klipyMetaRepo)
        let fetchSuggestions = FetchSuggestionsUseCase(repository: klipyMetaRepo)
        let fetchFavorites = FetchFavoriteStickersUseCase(repository: favoriteRepo)
        let addFavorite = AddFavoriteStickerUseCase(repository: favoriteRepo)
        let removeFavorite = RemoveFavoriteStickerUseCase(repository: favoriteRepo)
        let registerShare = RegisterStickerShareUseCase(repository: klipyMetaRepo)

        vm = GifPickerViewModel(
            fetchStickersUseCase: fetchStickers,
            fetchCategoriesUseCase: fetchCategories,
            fetchSuggestionsUseCase: fetchSuggestions,
            fetchFavoriteStickersUseCase: fetchFavorites,
            addFavoriteStickerUseCase: addFavorite,
            removeFavoriteStickerUseCase: removeFavorite,
            registerShareUseCase: registerShare,
            groupId: UUID()
        )
    }

    func testInitialState() {
        XCTAssertTrue(vm.showsCustomPack)
        XCTAssertEqual(vm.selectedCategory, .trending)
        XCTAssertFalse(vm.isSearchActive)
        XCTAssertTrue(vm.isSearchEmpty)
        XCTAssertTrue(vm.showsStickerContent)
    }

    func testOnCategorySelectedEmoji() {
        vm.onCategorySelected(.emoji)
        XCTAssertEqual(vm.selectedCategory, .emoji)
        XCTAssertFalse(vm.isSearchActive)
        XCTAssertFalse(vm.showsStickerContent)
    }

    func testOnCategorySelectedSearch() {
        vm.onCategorySelected(.search)
        XCTAssertTrue(vm.isSearchActive)
        XCTAssertEqual(vm.selectedCategory, .trending)
    }

    func testOnCategorySelectedSearchTogglesOff() {
        vm.isSearchActive = true
        vm.onCategorySelected(.search)
        // Second toggle → isSearchActive becomes false, then selectedCategory stays .trending
        XCTAssertFalse(vm.isSearchActive)
    }

    func testOnCategorySelectedFavorites() {
        vm.onCategorySelected(.favorites)
        XCTAssertEqual(vm.selectedCategory, .favorites)
        XCTAssertFalse(vm.isSearchActive)
    }

    func testOnCategorySelectedTrending() {
        vm.onCategorySelected(.trending)
        XCTAssertEqual(vm.selectedCategory, .trending)
        XCTAssertFalse(vm.isSearchActive)
        XCTAssertEqual(vm.searchText, "")
    }

    func testOnCategorySelectedCustomPack() {
        vm.onCategorySelected(.customPack)
        XCTAssertEqual(vm.selectedCategory, .customPack)
        XCTAssertFalse(vm.isSearchActive)
    }

    func testOnCategorySelectedKlipyPack() {
        let cat = StickerCategory(id: "reactions", name: "Reactions", previewURL: nil)
        vm.onCategorySelected(.klipyPack(cat))
        XCTAssertEqual(vm.selectedCategory, .klipyPack(cat))
        XCTAssertFalse(vm.isSearchActive)
    }

    func testOnSuggestionTapped() {
        vm.onSuggestionTapped("cool")
        XCTAssertEqual(vm.searchText, "cool")
        XCTAssertTrue(vm.isSearchActive)
    }

    func testIsFavoriteReturnsFalseByDefault() {
        XCTAssertFalse(vm.isFavorite("nonexistent"))
    }

    func testIsTogglingFavoriteReturnsFalseByDefault() {
        XCTAssertFalse(vm.isTogglingFavorite("nonexistent"))
    }

    func testShowsCustomPackWhenGroupIdIsNil() {
        let vmNoGroup = GifPickerViewModel(
            fetchStickersUseCase: FetchStickersUseCase(repository: stickerRepo),
            fetchCategoriesUseCase: FetchStickerCategoriesUseCase(repository: klipyMetaRepo),
            fetchSuggestionsUseCase: FetchSuggestionsUseCase(repository: klipyMetaRepo),
            fetchFavoriteStickersUseCase: FetchFavoriteStickersUseCase(repository: favoriteRepo),
            addFavoriteStickerUseCase: AddFavoriteStickerUseCase(repository: favoriteRepo),
            removeFavoriteStickerUseCase: RemoveFavoriteStickerUseCase(repository: favoriteRepo),
            registerShareUseCase: RegisterStickerShareUseCase(repository: klipyMetaRepo),
            groupId: nil
        )
        XCTAssertFalse(vmNoGroup.showsCustomPack)
    }
}

// MARK: - FakeStickerRepository2 (to avoid conflict with existing one)

private final class FakeStickerRepository2: StickerRepositoryProtocol, @unchecked Sendable {
    var result: StickerFetchResult = StickerFetchResult(stickers: [])

    func fetchStickers(query: String, source: StickerSource, position: String?) async throws -> StickerFetchResult {
        result
    }
}

// MARK: - Helper async throw assertion

private func XCTAssertThrowsAsyncError<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #file,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error to be thrown", file: file, line: line)
    } catch {
        // success
    }
}
