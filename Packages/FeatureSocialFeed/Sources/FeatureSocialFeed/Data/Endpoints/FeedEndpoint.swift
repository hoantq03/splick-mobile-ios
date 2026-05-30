import Foundation
import Networking

enum FeedEndpoint: APIEndpoint {
    case feed(page: Int, limit: Int)
    case photoAlbum(page: Int, limit: Int, filters: PhotoAlbumFilters)
    case post(id: UUID)
    case createPost(CreatePostRequestDTO)
    case addReaction(postId: UUID, CreateReactionRequestDTO)
    case removeReaction(postId: UUID, reactionId: UUID)
    case addComment(postId: UUID, CreateCommentRequestDTO)
    case deletePost(id: UUID)

    var path: String {
        switch self {
        case .feed: return "/v1/feed"
        case .photoAlbum: return "/v1/feed/photos"
        case .post(let id), .deletePost(let id): return "/v1/feed/posts/\(id)"
        case .createPost: return "/v1/feed/posts"
        case .addReaction(let postId, _): return "/v1/feed/posts/\(postId)/reactions"
        case .removeReaction(let postId, let reactionId):
            return "/v1/feed/posts/\(postId)/reactions/\(reactionId)"
        case .addComment(let postId, _): return "/v1/feed/posts/\(postId)/comments"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .feed, .post, .photoAlbum: return .get
        case .createPost, .addReaction, .addComment: return .post
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
        case .photoAlbum(let page, let limit, let filters):
            var items = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
            if let authorId = filters.author?.id {
                items.append(URLQueryItem(name: "authorId", value: authorId.uuidString))
            }
            if let groupId = filters.group?.id {
                items.append(URLQueryItem(name: "groupId", value: groupId.uuidString))
            }
            if let query = filters.apiCaptionQuery {
                items.append(URLQueryItem(name: "q", value: query))
            }
            return items
        default:
            return nil
        }
    }

    var body: Encodable? {
        switch self {
        case .createPost(let dto): return dto
        case .addReaction(_, let dto): return dto
        case .addComment(_, let dto): return dto
        default: return nil
        }
    }
}
