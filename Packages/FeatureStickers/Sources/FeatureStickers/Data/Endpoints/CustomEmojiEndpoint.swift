import Foundation
import Networking

enum CustomEmojiEndpoint: APIEndpoint {
    case listAll
    case listMine
    case create(request: CreateCustomEmojiRequestDTO)
    case delete(emojiId: UUID)

    var path: String {
        switch self {
        case .listAll:
            return "/v1/social/emojis"
        case .listMine, .create:
            return "/v1/social/users/me/emojis"
        case .delete(let emojiId):
            return "/v1/social/emojis/\(emojiId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listAll, .listMine:
            return .get
        case .create:
            return .post
        case .delete:
            return .delete
        }
    }

    var body: Encodable? {
        switch self {
        case .create(let request):
            return request
        case .listAll, .listMine, .delete:
            return nil
        }
    }
}
