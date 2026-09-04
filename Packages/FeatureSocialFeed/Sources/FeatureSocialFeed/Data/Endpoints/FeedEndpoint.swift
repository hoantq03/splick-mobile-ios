import Foundation
import Networking
import SplickDomain

enum FeedEndpoint: APIEndpoint {
    case feed(page: Int, limit: Int, authorId: UUID?)
    case feedAheadCount(afterCreatedAt: Date, afterId: UUID)
    case photoAlbumFirstPage(limit: Int, filters: PhotoAlbumFilters)
    case photoAlbumCursor(cursor: String, limit: Int, filters: PhotoAlbumFilters)
    case post(id: UUID)
    case postReactions(postId: UUID)
    case postComments(postId: UUID, page: Int, limit: Int, filter: CommentThreadFilter)
    case batchViewed(BatchViewPostsRequestDTO)
    case createPost(CreatePostRequestDTO)
    case addReaction(postId: UUID, CreateReactionRequestDTO)
    case removeReaction(postId: UUID, reactionId: UUID)
    case addComment(postId: UUID, CreateCommentRequestDTO)
    case deletePost(id: UUID)
    case updatePost(id: UUID, UpdatePostRequestDTO)
    case postEdits(id: UUID)
    case sendBillReminder(postId: UUID, SendPostBillReminderRequestDTO)
    case submitPaymentEvidence(postId: UUID, SubmitPaymentEvidenceRequestDTO)
    case approvePaymentEvidence(postId: UUID, evidenceId: UUID)
    case rejectPaymentEvidence(postId: UUID, evidenceId: UUID, RejectPaymentEvidenceRequestDTO)
    case streakSummary
    case streakCalendar(year: Int, month: Int)
    case streakDayPhotos(date: String)
    case searchLocations(query: String, limit: Int, lat: Double?, lon: Double?)
    case nearbyLocations(lat: Double, lon: Double, radius: Int, limit: Int)

    var path: String {
        switch self {
        case .feed: return "/v1/feed"
        case .feedAheadCount: return "/v1/feed/ahead-count"
        case .photoAlbumFirstPage, .photoAlbumCursor: return "/v1/feed/photos"
        case .post(let id), .deletePost(let id), .updatePost(let id, _): return "/v1/feed/posts/\(id)"
        case .postEdits(let id): return "/v1/feed/posts/\(id)/edits"
        case .postReactions(let postId): return "/v1/feed/posts/\(postId)/reactions"
        case .postComments(let postId, _, _, _): return "/v1/feed/posts/\(postId)/comments"
        case .batchViewed: return "/v1/feed/posts/batch-viewed"
        case .createPost: return "/v1/feed/posts"
        case .addReaction(let postId, _): return "/v1/feed/posts/\(postId)/reactions"
        case .removeReaction(let postId, let reactionId):
            return "/v1/feed/posts/\(postId)/reactions/\(reactionId)"
        case .addComment(let postId, _): return "/v1/feed/posts/\(postId)/comments"
        case .sendBillReminder(let postId, _): return "/v1/feed/posts/\(postId)/reminders"
        case .submitPaymentEvidence(let postId, _): return "/v1/feed/posts/\(postId)/payments/evidence"
        case .approvePaymentEvidence(let postId, let evidenceId):
            return "/v1/feed/posts/\(postId)/payments/evidence/\(evidenceId)/approve"
        case .rejectPaymentEvidence(let postId, let evidenceId, _):
            return "/v1/feed/posts/\(postId)/payments/evidence/\(evidenceId)/reject"
        case .streakSummary: return "/v1/feed/streak"
        case .streakCalendar: return "/v1/feed/streak/calendar"
        case .streakDayPhotos(let date): return "/v1/feed/streak/days/\(date)/photos"
        case .searchLocations: return "/v1/feed/locations/search"
        case .nearbyLocations: return "/v1/feed/locations/nearby"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .feed, .feedAheadCount, .post, .postReactions, .postComments, .photoAlbumFirstPage, .photoAlbumCursor,
             .streakSummary, .streakCalendar, .streakDayPhotos,
             .searchLocations, .nearbyLocations, .postEdits:
            return .get
        case .createPost, .addReaction, .addComment, .sendBillReminder,
             .submitPaymentEvidence, .approvePaymentEvidence, .rejectPaymentEvidence,
             .batchViewed:
            return .post
        case .updatePost: return .patch
        case .removeReaction, .deletePost: return .delete
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .feed(let page, let limit, let authorId):
            var items = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
            if let authorId {
                items.append(URLQueryItem(name: "authorId", value: authorId.uuidString))
            }
            return items
        case .feedAheadCount(let afterCreatedAt, let afterId):
            return [
                URLQueryItem(name: "afterCreatedAt", value: Self.iso8601String(from: afterCreatedAt)),
                URLQueryItem(name: "afterId", value: afterId.uuidString),
            ]
        case .photoAlbumFirstPage(let limit, let filters):
            return Self.photoAlbumQueryItems(page: 0, limit: limit, filters: filters)
        case .photoAlbumCursor(let cursor, let limit, let filters):
            return Self.photoAlbumQueryItems(cursor: cursor, limit: limit, filters: filters)
        case .streakCalendar(let year, let month):
            return [
                URLQueryItem(name: "year", value: "\(year)"),
                URLQueryItem(name: "month", value: "\(month)"),
            ]
        case .postComments(_, let page, let limit, let filter):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "filter", value: filter.apiValue),
            ]
        case .searchLocations(let query, let limit, let lat, let lon):
            var items = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
            if let lat { items.append(URLQueryItem(name: "lat", value: "\(lat)")) }
            if let lon { items.append(URLQueryItem(name: "lon", value: "\(lon)")) }
            return items
        case .nearbyLocations(let lat, let lon, let radius, let limit):
            return [
                URLQueryItem(name: "lat", value: "\(lat)"),
                URLQueryItem(name: "lon", value: "\(lon)"),
                URLQueryItem(name: "radius", value: "\(radius)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
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
        for author in filters.authors {
            items.append(URLQueryItem(name: "authorId", value: author.id.uuidString))
        }
        for group in filters.groups {
            items.append(URLQueryItem(name: "groupId", value: group.id.uuidString))
        }
        if let query = filters.apiCaptionQuery {
            items.append(URLQueryItem(name: "q", value: query))
        }
        if let feedKind = filters.feedKind {
            items.append(URLQueryItem(name: "feedKind", value: feedKind.rawValue))
        }
        return items
    }

    private static let feedInstantFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static func iso8601String(from date: Date) -> String {
        feedInstantFormatter.string(from: date)
    }

    var body: Encodable? {
        switch self {
        case .createPost(let dto): return dto
        case .updatePost(_, let dto): return dto
        case .batchViewed(let dto): return dto
        case .addReaction(_, let dto): return dto
        case .addComment(_, let dto): return dto
        case .sendBillReminder(_, let dto): return dto
        case .submitPaymentEvidence(_, let dto): return dto
        case .rejectPaymentEvidence(_, _, let dto): return dto
        default: return nil
        }
    }
}
