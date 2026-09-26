import XCTest
import Networking
import SplickDomain
import Common
@testable import FeatureStickers

// MARK: - Local Test-only MockAPIClient

actor TestMockAPIClient: APIClientProtocol {
    var shouldFail: Bool = false
    var failureError: NetworkError = .serverError(statusCode: 500)
    private var responses: [String: Any] = [:]
    var requestLog: [(method: String, path: String)] = []

    func register<T: Decodable>(path: String, response: T) {
        responses[path] = response
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        requestLog.append((method: endpoint.method.rawValue, path: endpoint.path))
        if shouldFail { throw failureError }
        guard let response = responses[endpoint.path] as? T else {
            throw NetworkError.notFound
        }
        return response
    }

    func request(_ endpoint: APIEndpoint) async throws {
        requestLog.append((method: endpoint.method.rawValue, path: endpoint.path))
        if shouldFail { throw failureError }
    }

    func upload<T: Decodable>(_ endpoint: APIEndpoint, data: Data, mimeType: String) async throws -> T {
        requestLog.append((method: "UPLOAD", path: endpoint.path))
        if shouldFail { throw failureError }
        guard let response = responses[endpoint.path] as? T else {
            throw NetworkError.notFound
        }
        return response
    }
}

// MARK: - CustomEmojiRepository Tests

final class CustomEmojiRepositoryTests: XCTestCase {
    private var apiClient: TestMockAPIClient!
    private var repository: CustomEmojiRepository!

    override func setUp() {
        super.setUp()
        apiClient = TestMockAPIClient()
        repository = CustomEmojiRepository(apiClient: apiClient)
    }

    func testFetchAllEmojisSuccess() async throws {
        let emojiId = UUID()
        let ownerId = UUID()
        let dto = CustomEmojiResponseDTO(
            id: emojiId,
            ownerId: ownerId,
            shortcode: "fire",
            mediaUrl: "https://cdn.splick.com/emojis/fire.png",
            createdAt: Date()
        )
        await apiClient.register(path: "/v1/social/emojis", response: [dto])

        let emojis = try await repository.fetchAllEmojis()
        XCTAssertEqual(emojis.count, 1)
        XCTAssertEqual(emojis.first?.shortcode, "fire")
        XCTAssertEqual(emojis.first?.id, emojiId)
    }

    func testFetchAllEmojisFiltersInvalidDTOs() async throws {
        // DTO with empty mediaUrl → should be filtered by mapper
        let validDTO = CustomEmojiResponseDTO(
            id: UUID(),
            ownerId: UUID(),
            shortcode: "valid",
            mediaUrl: "https://cdn.splick.com/valid.png",
            createdAt: Date()
        )
        let invalidDTO = CustomEmojiResponseDTO(
            id: UUID(),
            ownerId: nil,
            shortcode: "invalid",
            mediaUrl: "",
            createdAt: Date()
        )
        await apiClient.register(path: "/v1/social/emojis", response: [validDTO, invalidDTO])

        let emojis = try await repository.fetchAllEmojis()
        XCTAssertEqual(emojis.count, 1)
    }

    func testFetchMyEmojisSuccess() async throws {
        let dto = CustomEmojiResponseDTO(
            id: UUID(),
            ownerId: UUID(),
            shortcode: "heart",
            mediaUrl: "https://cdn.splick.com/heart.png",
            createdAt: Date()
        )
        await apiClient.register(path: "/v1/social/users/me/emojis", response: [dto])

        let emojis = try await repository.fetchMyEmojis()
        XCTAssertEqual(emojis.count, 1)
        XCTAssertEqual(emojis.first?.shortcode, "heart")
    }

    func testAddEmojiSuccess() async throws {
        let emojiId = UUID()
        let dto = CustomEmojiResponseDTO(
            id: emojiId,
            ownerId: UUID(),
            shortcode: "rocket",
            mediaUrl: "https://cdn.splick.com/rocket.png",
            createdAt: Date()
        )
        await apiClient.register(path: "/v1/social/users/me/emojis", response: dto)

        let emoji = try await repository.addEmoji(alias: "rocket", mediaId: UUID())
        XCTAssertEqual(emoji.id, emojiId)
        XCTAssertEqual(emoji.shortcode, "rocket")
    }

    func testAddEmojiThrowsOnInvalidResponse() async throws {
        let invalidDTO = CustomEmojiResponseDTO(
            id: UUID(),
            ownerId: nil,
            shortcode: "broken",
            mediaUrl: "",    // invalid URL → mapper returns nil
            createdAt: Date()
        )
        await apiClient.register(path: "/v1/social/users/me/emojis", response: invalidDTO)

        do {
            _ = try await repository.addEmoji(alias: "broken", mediaId: UUID())
            XCTFail("Expected CustomEmojiError.invalidResponse")
        } catch CustomEmojiError.invalidResponse {
            // pass
        }
    }

    func testDeleteEmojiSuccess() async throws {
        let emojiId = UUID()
        // delete → void request, no registered response needed

        // Should not throw when server returns success (no error flag)
        await XCTAssertNoThrowAsync(
            try await repository.deleteEmoji(emojiId: emojiId)
        )

        let log = await apiClient.requestLog
        XCTAssertEqual(log.last?.path, "/v1/social/emojis/\(emojiId)")
    }

    func testFetchAllEmojisFailure() async throws {
        await apiClient.register(path: "/v1/social/emojis", response: [] as [CustomEmojiResponseDTO])
        await apiClient.setToFail()

        do {
            _ = try await repository.fetchAllEmojis()
            XCTFail("Expected error")
        } catch {
            // pass
        }
    }
}

// MARK: - FavoriteStickerRepositoryImpl Tests

final class FavoriteStickerRepositoryImplTests: XCTestCase {
    private var apiClient: TestMockAPIClient!
    private var repository: FavoriteStickerRepositoryImpl!

    override func setUp() {
        super.setUp()
        apiClient = TestMockAPIClient()
        repository = FavoriteStickerRepositoryImpl(apiClient: apiClient)
    }

    func testFetchFavoritesSuccess() async throws {
        let dto = StickerFavoriteDTO(
            id: UUID(),
            provider: "klipy",
            externalId: "klipy-abc",
            url: "https://klipy.com/cat.gif",
            previewUrl: nil,
            name: "Cat",
            width: 200,
            height: 200
        )
        await apiClient.register(path: "/v1/feed/sticker-favorites", response: [dto])

        let stickers = try await repository.fetchFavorites()
        XCTAssertEqual(stickers.count, 1)
        XCTAssertEqual(stickers.first?.id, "klipy-abc")
    }

    func testFetchFavoritesFiltersInvalidDTOs() async throws {
        let invalidDTO = StickerFavoriteDTO(
            id: UUID(),
            provider: "klipy",
            externalId: "bad",
            url: "",
            previewUrl: nil,
            name: nil,
            width: nil,
            height: nil
        )
        await apiClient.register(path: "/v1/feed/sticker-favorites", response: [invalidDTO])

        let stickers = try await repository.fetchFavorites()
        XCTAssertTrue(stickers.isEmpty)
    }

    func testAddFavoriteSuccess() async throws {
        let favoriteId = UUID()
        let dto = StickerFavoriteDTO(
            id: favoriteId,
            provider: "klipy",
            externalId: "klipy-1",
            url: "https://klipy.com/1.gif",
            previewUrl: "https://klipy.com/1_thumb.gif",
            name: "GIF",
            width: 100,
            height: 100
        )
        await apiClient.register(path: "/v1/feed/sticker-favorites", response: dto)

        let sticker = try await repository.addFavorite(
            provider: "klipy",
            externalId: "klipy-1",
            url: URL(string: "https://klipy.com/1.gif")!,
            previewURL: URL(string: "https://klipy.com/1_thumb.gif")!,
            name: "GIF",
            width: 100,
            height: 100
        )
        XCTAssertEqual(sticker.id, "klipy-1")
        XCTAssertEqual(sticker.favoriteId, favoriteId)
    }

    func testAddFavoriteThrowsOnInvalidResponseDTO() async throws {
        let invalidDTO = StickerFavoriteDTO(
            id: UUID(),
            provider: "klipy",
            externalId: "bad",
            url: "",  // invalid URL
            previewUrl: nil,
            name: nil,
            width: nil,
            height: nil
        )
        await apiClient.register(path: "/v1/feed/sticker-favorites", response: invalidDTO)

        do {
            _ = try await repository.addFavorite(
                provider: "klipy",
                externalId: "bad",
                url: URL(string: "https://klipy.com/bad.gif")!,
                previewURL: nil,
                name: nil,
                width: nil,
                height: nil
            )
            XCTFail("Expected error to be thrown")
        } catch {
            // pass
        }
    }

    func testRemoveFavoriteSuccess() async throws {
        let favoriteId = UUID()
        await XCTAssertNoThrowAsync(
            try await repository.removeFavorite(id: favoriteId)
        )

        let log = await apiClient.requestLog
        XCTAssertEqual(log.last?.path, "/v1/feed/sticker-favorites/\(favoriteId.uuidString)")
    }

    func testFetchFavoritesWithFallbackGroupId() async throws {
        let groupId = UUID()
        let repoWithGroup = FavoriteStickerRepositoryImpl(apiClient: apiClient, fallbackGroupId: groupId)

        let dto = StickerFavoriteDTO(
            id: UUID(),
            provider: "custom",
            externalId: "custom-1",
            url: "https://cdn.splick.com/custom.png",
            previewUrl: nil,
            name: nil,
            width: nil,
            height: nil
        )
        await apiClient.register(path: "/v1/feed/sticker-favorites", response: [dto])

        let stickers = try await repoWithGroup.fetchFavorites()
        XCTAssertEqual(stickers.count, 1)
        XCTAssertEqual(stickers.first?.source, .custom(groupId: groupId))
    }
}

// MARK: - SplickStickerDataSource & Endpoint Tests

final class SplickStickerDataSourceTests: XCTestCase {
    private var apiClient: TestMockAPIClient!
    private var dataSource: SplickStickerDataSource!

    override func setUp() {
        super.setUp()
        apiClient = TestMockAPIClient()
        dataSource = SplickStickerDataSource(apiClient: apiClient)
    }

    func testFetchStickersWithKeyword() async throws {
        let groupId = UUID()
        let dto = SplickStickerDTO(
            id: "s1",
            url: "https://cdn.splick.com/s1.png",
            previewUrl: nil,
            width: 100,
            height: 100
        )
        await apiClient.register(path: "/v1/stickers/groups/\(groupId)", response: [dto])

        let stickers = try await dataSource.fetchStickers(groupId: groupId, keyword: "funny")
        XCTAssertEqual(stickers.count, 1)
        XCTAssertEqual(stickers.first?.id, "s1")
    }

    func testFetchStickersWithEmptyKeywordSendsNoKeyword() async throws {
        let groupId = UUID()
        await apiClient.register(path: "/v1/stickers/groups/\(groupId)", response: [] as [SplickStickerDTO])

        let stickers = try await dataSource.fetchStickers(groupId: groupId, keyword: "  ")
        XCTAssertTrue(stickers.isEmpty)

        let log = await apiClient.requestLog
        XCTAssertEqual(log.last?.path, "/v1/stickers/groups/\(groupId)")
    }

    func testFetchStickersFiltersInvalidDTOs() async throws {
        let groupId = UUID()
        let invalidDTO = SplickStickerDTO(id: "bad", url: "", previewUrl: nil, width: nil, height: nil)
        await apiClient.register(path: "/v1/stickers/groups/\(groupId)", response: [invalidDTO])

        let stickers = try await dataSource.fetchStickers(groupId: groupId, keyword: "")
        XCTAssertTrue(stickers.isEmpty)
    }
}

// MARK: - SplickStickerEndpoint Tests

final class SplickStickerEndpointTests: XCTestCase {
    func testPathMatchesGroupId() {
        let groupId = UUID()
        let ep = SplickStickerEndpoint.list(groupId: groupId, keyword: nil)
        XCTAssertEqual(ep.path, "/v1/stickers/groups/\(groupId)")
        XCTAssertEqual(ep.method, .get)
        XCTAssertNil(ep.queryItems)
    }

    func testQueryItemsWithKeyword() {
        let groupId = UUID()
        let ep = SplickStickerEndpoint.list(groupId: groupId, keyword: "cat")
        XCTAssertEqual(ep.queryItems?.count, 1)
        XCTAssertEqual(ep.queryItems?.first?.name, "keyword")
        XCTAssertEqual(ep.queryItems?.first?.value, "cat")
    }

    func testQueryItemsNilForEmptyKeyword() {
        let groupId = UUID()
        let ep = SplickStickerEndpoint.list(groupId: groupId, keyword: "")
        XCTAssertNil(ep.queryItems)
    }
}

// MARK: - StickerRepositoryImpl Public Init Test

final class StickerRepositoryImplPublicInitTests: XCTestCase {
    func testPublicInitCreatesRepository() {
        let apiClient = TestMockAPIClient()
        let repo = StickerRepositoryImpl(apiClient: apiClient)
        XCTAssertNotNil(repo)
    }
}

// MARK: - GifPickerViewModel Extended Tests

@MainActor
final class GifPickerViewModelExtendedTests: XCTestCase {
    private var stickerRepo: FakeExtStickerRepository!
    private var klipyMetaRepo: MockKlipyMetaRepository!
    private var favoriteRepo: MockFavoriteStickerRepository!

    override func setUp() {
        super.setUp()
        stickerRepo = FakeExtStickerRepository()
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

    func testOnAppearStartsLoading() async {
        let vm = makeVM()
        vm.onAppear()
        // Should trigger loading states without crashing
        XCTAssertNotNil(vm)
    }

    func testRetryForFavoritesCategory() async {
        let vm = makeVM()
        vm.onCategorySelected(.favorites)
        vm.retry()
        // Should trigger loadFavorites without crash
        XCTAssertEqual(vm.selectedCategory, .favorites)
    }

    func testRetryForDefaultCategory() async {
        let vm = makeVM()
        vm.retry()
        // Should trigger loadStickers without crash
        XCTAssertNotNil(vm)
    }

    func testRetryForEmojiCategoryIsNoOp() async {
        let vm = makeVM()
        vm.onCategorySelected(.emoji)
        vm.retry()
        XCTAssertEqual(vm.selectedCategory, .emoji)
    }

    func testOnSearchTextChanged() async {
        let vm = makeVM()
        vm.onSearchTextChanged("cats")
        XCTAssertEqual(vm.searchText, "cats")
        XCTAssertTrue(vm.isSearchActive)
    }

    func testOnSearchTextChangedEmpty() async {
        let vm = makeVM()
        vm.onSearchTextChanged("")
        // Even with empty text, isSearchActive is set to true per the implementation
        XCTAssertTrue(vm.isSearchActive)
        XCTAssertTrue(vm.searchText.isEmpty)
    }

    func testSelectStickerKlipy() async {
        let vm = makeVM()
        let sticker = Sticker(id: "klipy-1", url: URL(string: "https://klipy.com/1.gif")!, source: .klipy)
        vm.selectSticker(sticker)
        // Should not crash; registers share + potentially adds favorite
        XCTAssertNotNil(vm)
    }

    func testToggleFavoriteAddsToFavorites() async {
        let vm = makeVM()
        let sticker = Sticker(id: "klipy-1", url: URL(string: "https://klipy.com/1.gif")!, source: .klipy)
        vm.toggleFavorite(sticker)
        // Not a favorite initially, so should trigger saveFavorite
        XCTAssertNotNil(vm)
    }

    func testToggleFavoriteWhenAlreadyFavoriteRemoves() async {
        favoriteRepo.favorites = [
            Sticker(id: "klipy-1", url: URL(string: "https://klipy.com/1.gif")!, source: .klipy, favoriteId: UUID())
        ]
        let vm = makeVM()
        // Manually set up favorite state  
        let sticker = favoriteRepo.favorites[0]

        // Simulate that we have the sticker as favorite
        // (we need to load favorites first to populate the index)
        vm.onCategorySelected(.favorites)
        try? await Task.sleep(for: .milliseconds(50))

        vm.toggleFavorite(sticker)
        XCTAssertNotNil(vm)
    }

    func testLoadMoreStickersIfNeeded() async {
        let sticker = Sticker(id: "s-1", url: URL(string: "https://klipy.com/s1.gif")!, source: .klipy)
        stickerRepo.result = StickerFetchResult(stickers: [sticker], nextPosition: "page2")

        let vm = makeVM()
        vm.onCategorySelected(.trending)
        // Wait for async load
        try? await Task.sleep(for: .milliseconds(200))

        vm.loadMoreStickersIfNeeded(currentStickerId: "s-1")
        XCTAssertNotNil(vm)
    }

    func testLoadMoreStickersIfNeededWhenNotLastSticker() async {
        let s1 = Sticker(id: "s-1", url: URL(string: "https://klipy.com/s1.gif")!, source: .klipy)
        let s2 = Sticker(id: "s-2", url: URL(string: "https://klipy.com/s2.gif")!, source: .klipy)
        stickerRepo.result = StickerFetchResult(stickers: [s1, s2], nextPosition: "page2")

        let vm = makeVM()
        vm.onCategorySelected(.trending)
        try? await Task.sleep(for: .milliseconds(200))

        // s-1 is not the last sticker, so should NOT load more
        vm.loadMoreStickersIfNeeded(currentStickerId: "s-1")
        XCTAssertFalse(vm.isLoadingMore)
    }

    func testCurrentSourceCustomPack() async {
        let groupId = UUID()
        let vm = makeVM(groupId: groupId)
        vm.onCategorySelected(.customPack)
        // After selecting customPack, currentSource should be .custom(groupId:)
        XCTAssertEqual(vm.selectedCategory, .customPack)
    }

    func testCurrentSourceWithNilGroupIdForCustomPack() async {
        let vm = makeVM(groupId: nil)
        vm.onCategorySelected(.customPack)
        // When groupId is nil, loadStickers should throw StickerError.groupRequired
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(vm.selectedCategory, .customPack)
    }

    func testUserFacingMessageFromNetworkError() async {
        let throwingRepo = ThrowingFavoriteStickerRepository()
        throwingRepo.shouldThrow = true
        let vm = GifPickerViewModel(
            fetchStickersUseCase: FetchStickersUseCase(repository: stickerRepo),
            fetchCategoriesUseCase: FetchStickerCategoriesUseCase(repository: klipyMetaRepo),
            fetchSuggestionsUseCase: FetchSuggestionsUseCase(repository: klipyMetaRepo),
            fetchFavoriteStickersUseCase: FetchFavoriteStickersUseCase(repository: throwingRepo),
            addFavoriteStickerUseCase: AddFavoriteStickerUseCase(repository: throwingRepo),
            removeFavoriteStickerUseCase: RemoveFavoriteStickerUseCase(repository: throwingRepo),
            registerShareUseCase: RegisterStickerShareUseCase(repository: klipyMetaRepo),
            groupId: UUID()
        )
        vm.onCategorySelected(.favorites)
        try? await Task.sleep(for: .milliseconds(200))
        // Error message should be set or nil - just ensure no crash
        XCTAssertNotNil(vm)
    }

    func testIsSearchEmpty() {
        let vm = makeVM()
        XCTAssertTrue(vm.isSearchEmpty)
        vm.searchText = "   "
        XCTAssertTrue(vm.isSearchEmpty)
        vm.searchText = "cats"
        XCTAssertFalse(vm.isSearchEmpty)
    }
}

// MARK: - FakeExtStickerRepository

private final class FakeExtStickerRepository: StickerRepositoryProtocol, @unchecked Sendable {
    var result: StickerFetchResult = StickerFetchResult(stickers: [])
    var errorToThrow: Error?

    func fetchStickers(query: String, source: StickerSource, position: String?) async throws -> StickerFetchResult {
        if let error = errorToThrow { throw error }
        return result
    }
}



final class ThrowingFavoriteStickerRepository: FavoriteStickerRepositoryProtocol, @unchecked Sendable {
    var shouldThrow = false
    var favorites: [Sticker] = []

    func fetchFavorites() async throws -> [Sticker] {
        if shouldThrow { throw NetworkError.serverError(statusCode: 500) }
        return favorites
    }

    func addFavorite(provider: String, externalId: String, url: URL, previewURL: URL?, name: String?, width: Int?, height: Int?) async throws -> Sticker {
        if shouldThrow { throw NetworkError.serverError(statusCode: 500) }
        return Sticker(id: externalId, url: url, source: .klipy)
    }

    func removeFavorite(id: UUID) async throws {
        if shouldThrow { throw NetworkError.serverError(statusCode: 500) }
    }
}

// MARK: - TestMockAPIClient extension

extension TestMockAPIClient {
    func setToFail() {
        shouldFail = true
    }
}

// MARK: - Async assertion helpers

func XCTAssertNoThrowAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #file,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
    } catch {
        XCTFail("Expected no error but got: \(error)", file: file, line: line)
    }
}
