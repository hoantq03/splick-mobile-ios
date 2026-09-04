import Foundation
import Networking

enum StickerEndpoint: APIEndpoint {
    case groupStickers(groupId: UUID, keyword: String?)

    var path: String {
        switch self {
        case .groupStickers(let groupId, _):
            return "/v1/stickers/groups/\(groupId)"
        }
    }

    var method: HTTPMethod { .get }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .groupStickers(_, let keyword):
            guard let keyword, !keyword.isEmpty else { return nil }
            return [URLQueryItem(name: "keyword", value: keyword)]
        }
    }
}
