import Foundation
import Networking

enum FeedEndpoint: APIEndpoint {
    case feed(page: Int, limit: Int)
    case photoAlbumFirstPage(limit: Int, filters: PhotoAlbumFilters)
    case photoAlbumCursor(cursor: String, limit: Int, filters: PhotoAlbumFilters)
    case post(id: UUID)
    case createPost(CreatePostRequestDTO)
    case addReaction(postId: UUID, CreateReactionRequestDTO)
    case removeReaction(postId: UUID, reactionId: UUID)
    case addComment(postId: UUID, CreateCommentRequestDTO)
    case deletePost(id: UUID)

    var path: String {
        switch self {
        case .feed: return "/v1/feed"
        case .photoAlbumFirstPage, .photoAlbumCursor: return "/v1/feed/photos"
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
        case .feed, .post, .photoAlbumFirstPage, .photoAlbumCursor: return .get
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
        case .photoAlbumFirstPage(let limit, let filters):
            return Self.photoAlbumQueryItems(page: 0, limit: limit, filters: filters)
        case .photoAlbumCursor(let cursor, let limit, let filters):
            return Self.photoAlbumQueryItems(cursor: cursor, limit: limit, filters: filters)
        default:
            return nil
        }
    }

    private static func photoAlbumQueryItems(
        page: Int? = nil,
        cursor: String? = nil,
        limit: Int,
        filters: PhotoAlbumFilters
    ) -> [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        if let page {
            items.append(URLQueryItem(name: "page", value: "\(page)"))
        }
        if let cursor {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
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
