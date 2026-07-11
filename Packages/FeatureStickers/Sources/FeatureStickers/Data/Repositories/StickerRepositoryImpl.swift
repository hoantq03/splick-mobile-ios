import Foundation
import Networking
import SplickDomain

public final class StickerRepositoryImpl: StickerRepositoryProtocol, Sendable {
    private let klipyDataSource: KlipyDataSourceProtocol
    private let splickDataSource: SplickStickerDataSourceProtocol

    public init(apiClient: APIClientProtocol) {
        self.klipyDataSource = KlipyDataSource()
        self.splickDataSource = SplickStickerDataSource(apiClient: apiClient)
    }

    init(
        klipyDataSource: KlipyDataSourceProtocol,
        splickDataSource: SplickStickerDataSourceProtocol
    ) {
        self.klipyDataSource = klipyDataSource
        self.splickDataSource = splickDataSource
    }

    public func fetchStickers(query: String, source: StickerSource) async throws -> [Sticker] {
        switch source {
        case .klipy:
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return try await klipyDataSource.trending()
            }
            return try await klipyDataSource.search(query: trimmed)

        case .custom(let groupId):
            return try await splickDataSource.fetchStickers(groupId: groupId, keyword: query)
        }
    }
}
