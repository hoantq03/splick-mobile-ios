import Foundation
import Networking

enum CustomEmojiEndpoint: APIEndpoint {
    case list(groupId: UUID)
    case create(groupId: UUID, request: CreateCustomEmojiRequestDTO)
    case delete(groupId: UUID, emojiId: UUID)

    var path: String {
        switch self {
        case .list(let groupId), .create(let groupId, _):
            return "/v1/social/groups/\(groupId)/emojis"
        case .delete(let groupId, let emojiId):
            return "/v1/social/groups/\(groupId)/emojis/\(emojiId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list:
            return .get
        case .create:
            return .post
        case .delete:
            return .delete
        }
    }

    var body: Encodable? {
        switch self {
        case .create(_, let request):
            return request
        case .list, .delete:
            return nil
        }
    }
}
