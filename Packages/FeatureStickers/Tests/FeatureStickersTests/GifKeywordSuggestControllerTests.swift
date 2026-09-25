import XCTest
import SplickDomain
@testable import FeatureStickers

@MainActor
final class GifKeywordSuggestControllerTests: XCTestCase {
    func testRapidDraftChangesIssueOneSearch() async {
        let fetch = MockFetchStickersUseCase()
        let controller = GifKeywordSuggestController(
            fetchStickersUseCase: fetch,
            debounceMilliseconds: 40
        )

        controller.onDraftChanged("ca")
        controller.onDraftChanged("cat")
        controller.onDraftChanged("cats")

        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(fetch.queries, ["cats"])
        XCTAssertEqual(controller.testSearchCount, 1)
        XCTAssertEqual(controller.stickers.count, 1)
    }

    func testMentionActiveDoesNotSearch() async {
        let fetch = MockFetchStickersUseCase()
        let controller = GifKeywordSuggestController(
            fetchStickersUseCase: fetch,
            debounceMilliseconds: 0
        )
        controller.onDraftChanged("hello @ja", mentionActive: true)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertTrue(fetch.queries.isEmpty)
        XCTAssertTrue(controller.stickers.isEmpty)
    }
}

private final class MockFetchStickersUseCase: FetchStickersUseCaseProtocol, @unchecked Sendable {
    var queries: [String] = []

    func execute(
        query: String,
        source: StickerSource,
        position: String?
    ) async throws -> StickerFetchResult {
        queries.append(query)
        let sticker = Sticker(
            id: "gif-1",
            url: URL(string: "https://example.com/a.gif")!,
            source: .klipy
        )
        return StickerFetchResult(stickers: [sticker], nextPosition: nil)
    }
}
