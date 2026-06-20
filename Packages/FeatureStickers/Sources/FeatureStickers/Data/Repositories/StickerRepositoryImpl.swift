import Foundation
import Networking
import SplickDomain

public final class StickerRepositoryImpl: StickerRepositoryProtocol, Sendable {
    private let giphyDataSource: GiphyDataSourceProtocol
    private let splickDataSource: SplickStickerDataSourceProtocol

    public init(apiClient: APIClientProtocol) {
        self.giphyDataSource = GiphyDataSource()
        self.splickDataSource = SplickStickerDataSource(apiClient: apiClient)
    }

    init(
        giphyDataSource: GiphyDataSourceProtocol,
        splickDataSource: SplickStickerDataSourceProtocol
    ) {
        self.giphyDataSource = giphyDataSource
        self.splickDataSource = splickDataSource
    }

    public func fetchStickers(query: String, source: StickerSource) async throws -> [Sticker] {
        switch source {
        case .giphy:
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return try await giphyDataSource.trending()
            }
            return try await giphyDataSource.search(query: trimmed)

        case .custom(let groupId):
            return try await splickDataSource.fetchStickers(groupId: groupId, keyword: query)
        }
    }
}
