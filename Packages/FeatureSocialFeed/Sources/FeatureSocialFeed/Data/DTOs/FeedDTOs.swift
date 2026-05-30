import Foundation

struct CommentDTO: Decodable {
    let id: UUID
    let author: AuthorDTO
    let body: String?
    let parentCommentId: UUID?
    let attachments: [CommentAttachmentDTO]?
    let createdAt: Date
}

struct CommentAttachmentDTO: Decodable {
    let id: UUID
    let kind: String
    let mediaId: UUID?
    let url: String?
    let fileName: String?
    let thumbnailUrl: String?
    let sizeBytes: Int?
}

struct PostDTO: Decodable {
    let id: UUID
    let author: AuthorDTO
    let imageUrl: String?
    let thumbnailUrl: String?
    let caption: String?
    let reactions: [ReactionDTO]
    let groupId: UUID?
    let createdAt: Date
    let mediaType: String?
    let videoUrl: String?
    let videoDurationSeconds: Int?
    let companions: [AuthorDTO]?
    let feedKind: String?
    let checkInPlace: String?
    let location: PostLocationDTO?
    let mediaItems: [PostMediaItemDTO]?
    let billSplit: PostBillSplitDTO?
    let comments: [CommentDTO]?
    let viewCount: Int?
    let viewers: [AuthorDTO]?
}

struct PostLocationDTO: Decodable {
    let placeId: String?
    let displayName: String?
    let lat: Double?
    let lon: Double?
}

struct PostMediaItemDTO: Decodable {
    let id: UUID
    let mediaUrl: String
    let thumbnailUrl: String?
    let mediaType: String
    let durationSeconds: Int?
    let sortOrder: Int?
}

struct PostBillSplitDTO: Decodable {
    let totalAmount: String
    let currency: String
    let splits: [PostBillSplitLineDTO]
}

struct PostBillSplitLineDTO: Decodable {
    let id: UUID?
    let user: AuthorDTO
    let amount: String
}

struct AuthorDTO: Decodable {
    let id: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
}

struct ReactionDTO: Decodable {
    let id: UUID
    let emoji: String
    let userId: UUID
    let createdAt: Date
}

struct AlbumPhotoPageDTO: Decodable {
    let items: [AlbumPhotoDTO]
    let nextCursor: String?
}

struct AlbumPhotoDTO: Decodable {
    let mediaItemId: UUID
    let postId: UUID
    let author: AuthorDTO
    let groupId: UUID?
    let caption: String?
    let mediaUrl: String
    let thumbnailUrl: String?
    let mediaType: String
    let sortOrder: Int
    let createdAt: Date
}

struct CreateReactionRequestDTO: Encodable {
    let emoji: String
}

struct CreateCommentRequestDTO: Encodable {
    let body: String?
    let parentCommentId: UUID?
    let attachments: [CreateCommentAttachmentRequestDTO]?
}

struct CreateCommentAttachmentRequestDTO: Encodable {
    let kind: String
    let mediaId: UUID?
    let url: String
    let fileName: String?
    let thumbnailUrl: String?
    let sizeBytes: Int?
}

struct CreatePostRequestDTO: Encodable {
    let caption: String?
    let groupId: UUID?
    let feedKind: String
    let checkInPlace: String?
    let location: CreatePostLocationRequestDTO?
    let mediaItems: [CreatePostMediaItemRequestDTO]
    let companionIds: [UUID]
    let mediaId: UUID?
    let billSplit: CreatePostBillSplitRequestDTO?
}

struct CreatePostLocationRequestDTO: Encodable {
    let placeId: String?
    let displayName: String?
    let lat: Double?
    let lon: Double?
}

struct CreatePostMediaItemRequestDTO: Encodable {
    let mediaUrl: String
    let thumbnailUrl: String?
    let mediaType: String
    let durationSecs: Int?
    let sortOrder: Int?
}

struct CreatePostBillSplitRequestDTO: Encodable {
    let totalAmount: String
    let currency: String
    let splitType: String
    let participants: [UUID]
    let customAmounts: [String: String]?
}
