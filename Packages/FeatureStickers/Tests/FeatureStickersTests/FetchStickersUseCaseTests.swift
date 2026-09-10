import XCTest
@testable import FeatureStickers
import SplickDomain

final class FetchStickersUseCaseTests: XCTestCase {
    func testExecuteDelegatesToRepository() async throws {
        let repository = FakeStickerRepository(stickers: [
            Sticker(id: "1", url: URL(string: "https://static.klipy.com/1.gif")!, source: .klipy),
        ])
        let useCase = FetchStickersUseCase(repository: repository)

        let result = try await useCase.execute(query: "cat", source: .klipy, position: nil)

        XCTAssertEqual(result.stickers.count, 1)
        XCTAssertEqual(repository.lastQuery, "cat")
        XCTAssertEqual(repository.lastSource, .klipy)
    }
}

private final class FakeStickerRepository: StickerRepositoryProtocol, @unchecked Sendable {
    private let stickers: [Sticker]
    private(set) var lastQuery: String?
    private(set) var lastSource: StickerSource?

    init(stickers: [Sticker]) {
        self.stickers = stickers
    }

    func fetchStickers(
        query: String,
        source: StickerSource,
        position: String? = nil
    ) async throws -> StickerFetchResult {
        lastQuery = query
        lastSource = source
        return StickerFetchResult(stickers: stickers)
    }
}
