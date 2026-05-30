import Foundation
import SplickDomain

enum FeedMapper {
    static func toPost(_ dto: PostDTO) -> Post {
        let author = toUserSummary(dto.author)
        let sortedMediaDTOs = (dto.mediaItems ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
        let mappedMediaItems = sortedMediaDTOs.compactMap { toMediaItem($0) }

        let firstMediaItem = mappedMediaItems.first
        let fallbackImageUrl = dto.imageUrl ?? firstMediaItem?.mediaURL.absoluteString ?? "https://placeholder.splick.local/post.jpg"
        let imageURL = URL(string: fallbackImageUrl) ?? URL(string: "https://placeholder.splick.local/post.jpg")!
        let thumbnailURL = firstMediaItem?.thumbnailURL ?? dto.thumbnailUrl.flatMap(URL.init(string:))
        let videoURL =
            (firstMediaItem?.mediaType == .video
                ? firstMediaItem?.mediaURL
                : dto.videoUrl.flatMap(URL.init(string:)))
        let reactions = dto.reactions.map(toReaction)
        let comments = dto.comments?.map(toComment) ?? []
        let companions = dto.companions?.map(toUserSummary) ?? []
        let feedKind = PostFeedKind(rawValue: dto.feedKind ?? PostFeedKind.checkIn.rawValue) ?? .checkIn
        let mediaType = firstMediaItem?.mediaType
            ?? dto.mediaType.flatMap { PostMediaType(rawValue: $0) }
            ?? .image
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
            videoDurationSeconds: dto.videoDurationSeconds ?? firstMediaItem?.durationSeconds,
            mediaItems: mappedMediaItems,
            companions: companions,
            feedKind: feedKind,
            checkInPlace: dto.checkInPlace,
            billSplit: billSplit,
            viewCount: viewCount,
            viewers: viewers
        )
    }

    static func toMediaItem(_ dto: PostMediaItemDTO) -> PostMediaItem? {
        guard let mediaURL = URL(string: dto.mediaUrl) else { return nil }
        let mediaType = PostMediaType(rawValue: dto.mediaType.lowercased()) ?? .image
        return PostMediaItem(
            id: dto.id,
            mediaURL: mediaURL,
            thumbnailURL: dto.thumbnailUrl.flatMap(URL.init(string:)),
            mediaType: mediaType,
            durationSeconds: dto.durationSeconds,
            sortOrder: dto.sortOrder ?? 0
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

    static func toAlbumPhoto(_ dto: AlbumPhotoDTO) -> AlbumPhoto? {
        guard let mediaURL = URL(string: dto.mediaUrl) else { return nil }
        let mediaType = PostMediaType(rawValue: dto.mediaType.lowercased()) ?? .image
        return AlbumPhoto(
            id: dto.mediaItemId,
            postId: dto.postId,
            author: toUserSummary(dto.author),
            mediaURL: mediaURL,
            thumbnailURL: dto.thumbnailUrl.flatMap(URL.init(string:)),
            mediaType: mediaType,
            sortOrder: dto.sortOrder,
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
