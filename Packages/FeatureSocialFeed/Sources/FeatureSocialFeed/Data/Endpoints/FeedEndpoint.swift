import Foundation
import Networking

enum FeedEndpoint: APIEndpoint {
    case feed(page: Int, limit: Int)
    case post(id: UUID)
    case addReaction(postId: UUID, CreateReactionRequestDTO)
    case removeReaction(postId: UUID, reactionId: UUID)
    case deletePost(id: UUID)

    var path: String {
        switch self {
        case .feed: return "/v1/feed"
        case .post(let id): return "/v1/feed/posts/\(id)"
        case .addReaction(let postId, _): return "/v1/feed/posts/\(postId)/reactions"
        case .removeReaction(let postId, let reactionId):
            return "/v1/feed/posts/\(postId)/reactions/\(reactionId)"
        case .deletePost(let id): return "/v1/feed/posts/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .feed, .post: return .get
        case .addReaction: return .post
        case .removeReaction, .deletePost: return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .feed(let page, let limit):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
        default: return nil
        }
    }

    var body: Encodable? {
        switch self {
        case .addReaction(_, let dto): return dto
        default: return nil
        }
    }
}
