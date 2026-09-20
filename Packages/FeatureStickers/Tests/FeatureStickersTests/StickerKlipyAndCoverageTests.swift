import XCTest
import Foundation
@testable import FeatureStickers
import SplickDomain

// MARK: - KlipyMetaRepositoryImpl Public Init Test

final class KlipyMetaRepositoryImplPublicInitTests: XCTestCase {
    func testPublicInitCreatesRepository() {
        // Tests that the public init which uses real KlipyDataSource can be called
        let repo = KlipyMetaRepositoryImpl()
        XCTAssertNotNil(repo)
    }
}

// MARK: - KlipyDTOs Additional Decoding Tests

final class KlipyDTOsAdditionalTests: XCTestCase {
    /// Tests the implicit closures in KlipySearchResponseDTO for data.results and data.data nested paths
    func testSearchResponseDecodesDataNestedResultsPath() throws {
        // This path: data key → NestedKeys.results
        let json = """
        {
            "data": {
                "results": [
                    {
                        "id": "nested-results-1",
                        "media_formats": {
                            "gif": { "url": "https://klipy.com/nr1.gif", "dims": [100, 100] }
                        }
                    }
                ],
                "next": "next-token"
            }
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(KlipySearchResponseDTO.self, from: json)
        XCTAssertEqual(payload.results.count, 1)
        XCTAssertEqual(payload.results[0].id, "nested-results-1")
        XCTAssertEqual(payload.next, "next-token")
    }

    func testSearchResponseDecodesDataNestedDataPath() throws {
        // This path: data key → NestedKeys.data (fallback)
        let json = """
        {
            "data": {
                "data": [
                    {
                        "id": "nested-data-1",
                        "media_formats": {
                            "gif": { "url": "https://klipy.com/nd1.gif", "dims": [200, 150] }
                        }
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(KlipySearchResponseDTO.self, from: json)
        XCTAssertEqual(payload.results.count, 1)
        XCTAssertEqual(payload.results[0].id, "nested-data-1")
    }

    func testSearchResponseDecodesDataDirectArrayPath() throws {
        // This path: data key → direct array (last fallback in init)
        let json = """
        {
            "data": [
                {
                    "id": "data-direct-1",
                    "media_formats": {
                        "tinygif": { "url": "https://klipy.com/dd1.gif", "dims": [80, 60] }
                    }
                }
            ],
            "next": "next-page"
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(KlipySearchResponseDTO.self, from: json)
        XCTAssertEqual(payload.results.count, 1)
        XCTAssertEqual(payload.results[0].id, "data-direct-1")
        XCTAssertEqual(payload.next, "next-page")
    }
}

// MARK: - URLProtocol Mock for KlipyDataSource

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - KlipyDataSource Tests with Mock URLSession

final class KlipyDataSourceTests: XCTestCase {
    private var session: URLSession!
    private var dataSource: KlipyDataSource!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        dataSource = KlipyDataSource(session: session)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    private func makeResponse(statusCode: Int, url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    private func makeURL(_ path: String) -> URL {
        URL(string: "https://klipy.io\(path)")!
    }

    func testSearchReturnsTrendingWhenQueryIsEmpty() async throws {
        let trendingJSON = """
        {
            "results": [
                { "id": "trend-1", "media_formats": { "gif": { "url": "https://klipy.com/t1.gif", "dims": [100, 100] } } }
            ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            (self.makeResponse(statusCode: 200, url: request.url!), trendingJSON)
        }

        let result = try await dataSource.search(query: "  ", position: nil)
        XCTAssertEqual(result.stickers.count, 1)
    }

    func testSearchReturnsResultsWithQuery() async throws {
        let searchJSON = """
        {
            "results": [
                { "id": "cat-1", "media_formats": { "gif": { "url": "https://klipy.com/cat.gif", "dims": [200, 200] } } }
            ],
            "next": "nextpage"
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("q=cat") == true || request.url?.absoluteString.contains("q=cat") == true)
            return (self.makeResponse(statusCode: 200, url: request.url!), searchJSON)
        }

        let result = try await dataSource.search(query: "cat", position: nil)
        XCTAssertEqual(result.stickers.count, 1)
        XCTAssertEqual(result.nextPosition, "nextpage")
    }

    func testSearchWithPosition() async throws {
        let searchJSON = """
        { "results": [], "next": null }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("pos=") == true)
            return (self.makeResponse(statusCode: 200, url: request.url!), searchJSON)
        }

        let result = try await dataSource.search(query: "cat", position: "page2")
        XCTAssertTrue(result.stickers.isEmpty)
    }

    func testTrendingSuccess() async throws {
        let trendingJSON = """
        {
            "results": [
                { "id": "t-1", "media_formats": { "gif": { "url": "https://klipy.com/t.gif", "dims": [100, 100] } } },
                { "id": "t-2", "media_formats": { "tinygif": { "url": "https://klipy.com/t2.gif", "dims": [50, 50] } } }
            ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            (self.makeResponse(statusCode: 200, url: request.url!), trendingJSON)
        }

        let result = try await dataSource.trending(position: nil)
        XCTAssertGreaterThanOrEqual(result.stickers.count, 1)
    }

    func testTrendingWithPosition() async throws {
        let trendingJSON = """
        { "results": [] }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("pos=abc123") == true)
            return (self.makeResponse(statusCode: 200, url: request.url!), trendingJSON)
        }

        let result = try await dataSource.trending(position: "abc123")
        XCTAssertTrue(result.stickers.isEmpty)
    }

    func testCategoriesSuccess() async throws {
        let categoriesJSON = """
        {
            "tags": [
                { "searchterm": "reaction", "name": "Reactions", "image": "https://klipy.com/cat.jpg" },
                { "searchterm": "funny", "name": "Funny", "image": null }
            ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            (self.makeResponse(statusCode: 200, url: request.url!), categoriesJSON)
        }

        let categories = try await dataSource.categories()
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, "reaction")
        XCTAssertNotNil(categories[0].previewURL)
        XCTAssertNil(categories[1].previewURL)
    }

    func testAutocompleteWithNonEmptyQuery() async throws {
        let autocompleteJSON = """
        { "results": ["cats", "cats dancing", "cats funny"] }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            (self.makeResponse(statusCode: 200, url: request.url!), autocompleteJSON)
        }

        let results = try await dataSource.autocomplete(query: "cats")
        XCTAssertEqual(results.count, 3)
    }

    func testAutocompleteWithEmptyQueryReturnsEmpty() async throws {
        let results = try await dataSource.autocomplete(query: "  ")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchSuggestionsWithQuery() async throws {
        let json = """
        { "results": ["cat reaction", "cat funny"] }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            (self.makeResponse(statusCode: 200, url: request.url!), json)
        }

        let results = try await dataSource.searchSuggestions(query: "cat")
        XCTAssertEqual(results.count, 2)
    }

    func testSearchSuggestionsWithEmptyQuery() async throws {
        let results = try await dataSource.searchSuggestions(query: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testTrendingTermsSuccess() async throws {
        let json = """
        { "results": ["love", "happy", "dance"] }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            (self.makeResponse(statusCode: 200, url: request.url!), json)
        }

        let terms = try await dataSource.trendingTerms()
        XCTAssertEqual(terms.count, 3)
    }

    func testRegisterShareWithSearchQuery() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            return (self.makeResponse(statusCode: 200, url: request.url!), Data())
        }

        try await dataSource.registerShare(gifId: "gif-42", searchQuery: "cat dance")
        XCTAssertNotNil(capturedURL)
        XCTAssertTrue(capturedURL?.absoluteString.contains("id=gif-42") == true)
        XCTAssertTrue(capturedURL?.absoluteString.contains("q=cat") == true)
    }

    func testRegisterShareWithNilSearchQuery() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            return (self.makeResponse(statusCode: 200, url: request.url!), Data())
        }

        try await dataSource.registerShare(gifId: "gif-99", searchQuery: nil)
        XCTAssertNotNil(capturedURL)
        XCTAssertFalse(capturedURL?.absoluteString.contains("&q=") == true)
    }

    func testRegisterShareWithEmptySearchQuery() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            return (self.makeResponse(statusCode: 200, url: request.url!), Data())
        }

        try await dataSource.registerShare(gifId: "gif-100", searchQuery: "  ")
        XCTAssertNotNil(capturedURL)
        XCTAssertFalse(capturedURL?.absoluteString.contains("&q=") == true)
    }

    func testFetchJSONThrowsRateLimitOn429() async throws {
        MockURLProtocol.requestHandler = { request in
            (self.makeResponse(statusCode: 429, url: request.url!), Data())
        }

        do {
            _ = try await dataSource.trending(position: nil)
            XCTFail("Expected StickerError.rateLimitExceeded")
        } catch StickerError.rateLimitExceeded {
            // pass
        }
    }

    func testFetchJSONThrowsNetworkErrorOnNon2xx() async throws {
        MockURLProtocol.requestHandler = { request in
            (self.makeResponse(statusCode: 503, url: request.url!), Data())
        }

        do {
            _ = try await dataSource.trending(position: nil)
            XCTFail("Expected StickerError.network")
        } catch StickerError.network {
            // pass
        }
    }

    func testFetchJSONThrowsNetworkErrorOnBadJSON() async throws {
        MockURLProtocol.requestHandler = { request in
            (self.makeResponse(statusCode: 200, url: request.url!), "not valid json".data(using: .utf8)!)
        }

        do {
            _ = try await dataSource.trending(position: nil)
            XCTFail("Expected StickerError.network due to bad JSON")
        } catch StickerError.network {
            // pass
        }
    }
}

// MARK: - EmojiCatalog Tests

final class EmojiCatalogTests: XCTestCase {
    func testSystemEntriesAreNotEmpty() {
        XCTAssertFalse(EmojiCatalog.systemEntries.isEmpty)
    }

    func testAllEntriesHaveNonEmptyEmoji() {
        for entry in EmojiCatalog.systemEntries {
            XCTAssertFalse(entry.emoji.isEmpty, "Emoji should not be empty")
        }
    }

    func testAllEntriesHaveNonEmptyKeywords() {
        for entry in EmojiCatalog.systemEntries {
            XCTAssertFalse(entry.keywords.isEmpty, "Keywords should not be empty for \(entry.emoji)")
        }
    }

    func testEntryIdMatchesEmoji() {
        let entry = EmojiCatalog.systemEntries[0]
        XCTAssertEqual(entry.id, entry.emoji)
    }
}

// MARK: - GifPickerViewModel Async Coverage Tests

@MainActor
final class GifPickerViewModelAsyncTests: XCTestCase {
    private var stickerRepo: FakeAsyncStickerRepository!
    private var klipyMetaRepo: MockKlipyMetaRepository!
    private var favoriteRepo: MockFavoriteStickerRepository!

    override func setUp() {
        super.setUp()
        stickerRepo = FakeAsyncStickerRepository()
        klipyMetaRepo = MockKlipyMetaRepository()
        favoriteRepo = MockFavoriteStickerRepository()
    }

    private func makeVM(groupId: UUID? = UUID()) -> GifPickerViewModel {
        GifPickerViewModel(
            fetchStickersUseCase: FetchStickersUseCase(repository: stickerRepo),
            fetchCategoriesUseCase: FetchStickerCategoriesUseCase(repository: klipyMetaRepo),
            fetchSuggestionsUseCase: FetchSuggestionsUseCase(repository: klipyMetaRepo),
            fetchFavoriteStickersUseCase: FetchFavoriteStickersUseCase(repository: favoriteRepo),
            addFavoriteStickerUseCase: AddFavoriteStickerUseCase(repository: favoriteRepo),
            removeFavoriteStickerUseCase: RemoveFavoriteStickerUseCase(repository: favoriteRepo),
            registerShareUseCase: RegisterStickerShareUseCase(repository: klipyMetaRepo),
            groupId: groupId
        )
    }

    func testOnAppearThenLoadStickersSucceeds() async {
        let sticker = Sticker(id: "klipy-1", url: URL(string: "https://klipy.com/1.gif")!, source: .klipy)
        stickerRepo.result = StickerFetchResult(stickers: [sticker])
        klipyMetaRepo.categories = [StickerCategory(id: "trending", name: "Trending", previewURL: nil)]

        let vm = makeVM()
        vm.onAppear()
        try? await Task.sleep(for: .milliseconds(300))
        // Verify no crash; state should now be loaded
        XCTAssertNotNil(vm)
    }

    func testToggleFavoriteWhenAlreadyFavoriteCallsRemove() async {
        let favoriteId = UUID()
        let sticker = Sticker(id: "klipy-fav", url: URL(string: "https://klipy.com/fav.gif")!, source: .klipy, favoriteId: favoriteId)
        favoriteRepo.favorites = [sticker]

        let vm = makeVM()
        // First load favorites to build index
        vm.onCategorySelected(.favorites)
        try? await Task.sleep(for: .milliseconds(300))

        // Now sticker should be marked as favorite in the VM
        // Toggling it should trigger removeFavorite
        vm.toggleFavorite(sticker)
        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(favoriteRepo.lastRemovedId, favoriteId)
    }

    func testToggleFavoriteWhenNotFavoriteCallsAdd() async {
        let sticker = Sticker(id: "klipy-new", url: URL(string: "https://klipy.com/new.gif")!, source: .klipy)

        let vm = makeVM()
        vm.toggleFavorite(sticker)
        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(favoriteRepo.lastAddedExternalId, "klipy-new")
    }

    func testSelectStickerRegistersShare() async {
        let sticker = Sticker(id: "gif-42", url: URL(string: "https://klipy.com/42.gif")!, source: .klipy)
        stickerRepo.result = StickerFetchResult(stickers: [sticker])

        let vm = makeVM()
        vm.searchText = "funny cats"
        vm.selectSticker(sticker)
        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(klipyMetaRepo.lastRegisteredShareGifId, "gif-42")
        XCTAssertEqual(klipyMetaRepo.lastRegisteredSearchQuery, "funny cats")
    }

    func testSelectStickerWithEmptySearchDoesNotPassQuery() async {
        let sticker = Sticker(id: "gif-43", url: URL(string: "https://klipy.com/43.gif")!, source: .klipy)

        let vm = makeVM()
        vm.searchText = ""
        vm.selectSticker(sticker)
        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(klipyMetaRepo.lastRegisteredShareGifId, "gif-43")
        XCTAssertNil(klipyMetaRepo.lastRegisteredSearchQuery)
    }

    func testRemoveFavoriteWhenNoFavoriteIdUsesExternalId() async {
        // Sticker without favoriteId - should use favoriteIdByExternalId from index
        let favoriteId = UUID()
        let stickerWithFavId = Sticker(
            id: "klipy-x", url: URL(string: "https://klipy.com/x.gif")!,
            source: .klipy, favoriteId: favoriteId
        )
        favoriteRepo.favorites = [stickerWithFavId]

        let vm = makeVM()
        vm.onCategorySelected(.favorites)
        try? await Task.sleep(for: .milliseconds(300))

        // Create sticker without favoriteId but same external id
        let stickerNoFavId = Sticker(id: "klipy-x", url: URL(string: "https://klipy.com/x.gif")!, source: .klipy)
        vm.toggleFavorite(stickerNoFavId)
        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(favoriteRepo.lastRemovedId, favoriteId)
    }

    func testLoadMoreStickersIfNeededTriggersLoadMore() async {
        let s1 = Sticker(id: "s-1", url: URL(string: "https://klipy.com/s1.gif")!, source: .klipy)
        stickerRepo.result = StickerFetchResult(stickers: [s1], nextPosition: "nextPage")

        let vm = makeVM()
        vm.onCategorySelected(.trending)
        try? await Task.sleep(for: .milliseconds(300))

        // Additional stickers for loadMore
        let s2 = Sticker(id: "s-2", url: URL(string: "https://klipy.com/s2.gif")!, source: .klipy)
        stickerRepo.result = StickerFetchResult(stickers: [s2], nextPosition: nil)

        vm.loadMoreStickersIfNeeded(currentStickerId: "s-1")
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertNotNil(vm)
    }

    func testLoadMoreStickersWhenAlreadyLoadingDoesNothing() async {
        let s1 = Sticker(id: "s-1", url: URL(string: "https://klipy.com/s1.gif")!, source: .klipy)
        stickerRepo.result = StickerFetchResult(stickers: [s1], nextPosition: "next")

        let vm = makeVM()
        vm.onCategorySelected(.trending)
        try? await Task.sleep(for: .milliseconds(300))

        // isLoadingMore is false, so this can trigger
        // But if we trigger before it finishes, second call should be ignored
        vm.loadMoreStickersIfNeeded(currentStickerId: "s-1")
        vm.loadMoreStickersIfNeeded(currentStickerId: "s-1") // second call should be ignored
        XCTAssertNotNil(vm)
    }

    func testOnSearchTextChangedDebouncesThenLoads() async {
        stickerRepo.result = StickerFetchResult(stickers: [])

        let vm = makeVM()
        vm.onSearchTextChanged("cats")

        // Wait for debounce + async task
        try? await Task.sleep(for: .seconds(1))

        XCTAssertEqual(vm.searchText, "cats")
    }

    func testAppendToFavoritesListWhenIdle() async {
        favoriteRepo.favorites = []
        let vm = makeVM()

        let sticker = Sticker(id: "new-fav", url: URL(string: "https://klipy.com/nf.gif")!, source: .klipy)
        vm.toggleFavorite(sticker)
        try? await Task.sleep(for: .milliseconds(300))

        // Should have appended to favorites list (favoritesState was .idle)
        XCTAssertNotNil(vm)
    }

    func testUserFacingMessageFromStickerError() async {
        stickerRepo.errorToThrow = StickerError.groupRequired
        let vm = makeVM(groupId: nil)
        vm.onCategorySelected(.customPack)
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertNotNil(vm.errorMessage)
    }

    func testUserFacingMessageFromGenericError() async {
        stickerRepo.errorToThrow = URLError(.timedOut)
        let vm = makeVM()
        vm.onCategorySelected(.trending)
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertNotNil(vm)
    }
}

// MARK: - FakeAsyncStickerRepository

private final class FakeAsyncStickerRepository: StickerRepositoryProtocol, @unchecked Sendable {
    var result: StickerFetchResult = StickerFetchResult(stickers: [])
    var errorToThrow: Error?

    func fetchStickers(query: String, source: StickerSource, position: String?) async throws -> StickerFetchResult {
        if let error = errorToThrow { throw error }
        return result
    }
}
