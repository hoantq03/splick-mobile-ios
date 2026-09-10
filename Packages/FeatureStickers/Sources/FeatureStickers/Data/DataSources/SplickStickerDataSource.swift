import Foundation
import Networking
import SplickDomain

enum SplickStickerEndpoint: APIEndpoint {
    case list(groupId: UUID, keyword: String?)

    var path: String {
        switch self {
        case .list(let groupId, _):
            return "/v1/stickers/groups/\(groupId)"
        }
    }

    var method: HTTPMethod { .get }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .list(_, let keyword):
            guard let keyword, !keyword.isEmpty else { return nil }
            return [URLQueryItem(name: "keyword", value: keyword)]
        }
    }
}

protocol SplickStickerDataSourceProtocol: Sendable {
    func fetchStickers(groupId: UUID, keyword: String) async throws -> [Sticker]
}

final class SplickStickerDataSource: SplickStickerDataSourceProtocol, @unchecked Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func fetchStickers(groupId: UUID, keyword: String) async throws -> [Sticker] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let dtos: [SplickStickerDTO] = try await apiClient.request(
            SplickStickerEndpoint.list(groupId: groupId, keyword: trimmed.isEmpty ? nil : trimmed)
        )
        return dtos.compactMap { StickerMapper.toSticker($0, groupId: groupId) }
    }
}
