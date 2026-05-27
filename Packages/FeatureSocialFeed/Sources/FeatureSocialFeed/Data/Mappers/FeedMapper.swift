import Foundation
import SplickDomain

enum FeedMapper {
    static func toPost(_ dto: PostDTO) -> Post {
        let author = toUserSummary(dto.author)
        let imageURL = URL(string: dto.imageUrl)!
        let thumbnailURL = dto.thumbnailUrl.flatMap(URL.init(string:))
        let videoURL = dto.videoUrl.flatMap(URL.init(string:))
        let reactions = dto.reactions.map(toReaction)
        let comments = dto.comments?.map(toComment) ?? []
        let companions = dto.companions?.map(toUserSummary) ?? []
        let feedKind = PostFeedKind(rawValue: dto.feedKind ?? PostFeedKind.checkIn.rawValue) ?? .checkIn
        let mediaType = dto.mediaType.flatMap { PostMediaType(rawValue: $0) } ?? .image
        let billSplit = dto.billSplit.map(toBillSplit)
        let viewCount = dto.viewCount ?? 0
        let viewers = dto.viewers?.map(toUserSummary) ?? []

        return Post(
            id: dto.id,
            author: author,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            caption: dto.caption,
            reactions: reactions,
            comments: comments,
            groupId: dto.groupId,
            createdAt: dto.createdAt,
            mediaType: mediaType,
            videoURL: videoURL,
            videoDurationSeconds: dto.videoDurationSeconds,
            companions: companions,
            feedKind: feedKind,
            checkInPlace: dto.checkInPlace,
            billSplit: billSplit,
            viewCount: viewCount,
            viewers: viewers
        )
    }

    static func toComment(_ dto: CommentDTO) -> PostComment {
        PostComment(
            id: dto.id,
            author: toUserSummary(dto.author),
            text: dto.body,
            attachments: dto.attachments?.map(toCommentAttachment) ?? [],
            parentCommentId: dto.parentCommentId,
            createdAt: dto.createdAt
        )
    }

    static func toCommentAttachment(_ dto: CommentAttachmentDTO) -> CommentAttachment {
        CommentAttachment(
            id: dto.id,
            kind: CommentAttachmentKind(rawValue: dto.kind) ?? .file,
            url: dto.url.flatMap(URL.init(string:)),
            fileName: dto.fileName,
            thumbnailURL: dto.thumbnailUrl.flatMap(URL.init(string:)),
            sizeBytes: dto.sizeBytes ?? 0
        )
    }

    static func toReaction(_ dto: ReactionDTO) -> Reaction {
        Reaction(
            id: dto.id,
            emoji: dto.emoji,
            userId: dto.userId,
            createdAt: dto.createdAt
        )
    }

    static func toUserSummary(_ dto: AuthorDTO) -> UserSummary {
        UserSummary(
            id: dto.id,
            username: dto.username,
            displayName: dto.displayName,
            avatarURL: dto.avatarUrl.flatMap(URL.init(string:))
        )
    }

    static func toBillSplit(_ dto: PostBillSplitDTO) -> PostBillSplit {
        let splits = dto.splits.map(toBillSplitLine)
        let totalAmount = Decimal(string: dto.totalAmount) ?? 0
        return PostBillSplit(
            totalAmount: totalAmount,
            currency: dto.currency,
            splits: splits
        )
    }

    private static func toBillSplitLine(_ line: PostBillSplitLineDTO) -> PostBillSplitLine {
        let amount = Decimal(string: line.amount) ?? 0
        return PostBillSplitLine(
            id: line.id ?? UUID(),
            user: toUserSummary(line.user),
            amount: amount
        )
    }
}
