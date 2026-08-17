import Foundation

struct CommentDTO: Decodable {
    let id: UUID
    let author: AuthorDTO
    let body: String?
    let parentCommentId: UUID?
    let attachments: [CommentAttachmentDTO]?
    let createdAt: Date
    let updatedAt: Date?
    let deletedAt: Date?
    let commentType: String?
    let evidenceId: UUID?
    let splitId: UUID?
    let evidenceStatus: String?
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
    let reactions: [ReactionDTO]?
    let reactionCount: Int?
    let reactorCount: Int?
    let reactionPreview: [ReactionUserSummaryDTO]?
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
    let commentCount: Int?
    let viewCount: Int?
    let viewers: [AuthorDTO]?
    let audience: PostAudienceDTO?
    let reactionCount: Int?
    let reactorCount: Int?
    let reactionPreview: [ReactionUserSummaryDTO]?
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
    let widthPx: Int?
    let heightPx: Int?
    let sortOrder: Int?
}

struct PostAudienceDTO: Decodable {
    let mode: String?
    let allowedGroupIds: [UUID]?
    let allowedUserIds: [UUID]?
    let excludedUserIds: [UUID]?
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
    let isPaid: Bool?
    let paymentStatus: String?
    let latestEvidenceCommentId: UUID?
    let lastRejectedAt: Date?
    let reminderCount: Int?
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

struct EmojiCountDTO: Decodable {
    let emoji: String
    let count: Int
}

struct ReactionUserSummaryDTO: Decodable {
    let user: AuthorDTO
    let emojiCounts: [EmojiCountDTO]
}

struct PostReactionsDTO: Decodable {
    let reactionCount: Int
    let reactorCount: Int
    let items: [ReactionUserSummaryDTO]
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
    let audience: CreatePostAudienceRequestDTO?
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

struct CreatePostAudienceRequestDTO: Encodable {
    let mode: String
    let allowedGroupIds: [UUID]
    let allowedUserIds: [UUID]
    let excludedUserIds: [UUID]
}

struct CreatePostBillSplitRequestDTO: Encodable {
    let totalAmount: String
    let currency: String
    let splitType: String
    let participants: [UUID]
    let customAmounts: [String: String]?
    let autoReminderEnabled: Bool?
}

struct SendPostBillReminderRequestDTO: Encodable {
    let targetUserIds: [UUID]?
    let message: String
    let attachments: [CreateCommentAttachmentRequestDTO]
}

struct SendPostBillReminderResponseDTO: Decodable {
    let sentCount: Int
    let skippedCount: Int
}

struct SubmitPaymentEvidenceRequestDTO: Encodable {
    let splitId: UUID
    let message: String?
    let attachments: [CreateCommentAttachmentRequestDTO]
}

struct SubmitPaymentEvidenceResponseDTO: Decodable {
    let evidenceId: UUID
    let commentId: UUID
}

struct RejectPaymentEvidenceRequestDTO: Encodable {
    let reason: String
}

struct BatchViewPostsRequestDTO: Encodable {
    let postIds: [UUID]
}

struct StreakSummaryDTO: Decodable {
    let currentStreak: Int
    let hasTodayPhoto: Bool
}

struct StreakDayDTO: Decodable {
    let date: String
    let firstPhotoUrl: String?
    let firstThumbnailUrl: String?
    let photoCount: Int
}
