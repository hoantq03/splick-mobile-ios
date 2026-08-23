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
        let reactions = (dto.reactions ?? []).map(toReaction)
        let serverPreview = dto.reactionPreview?.map(toReactionUserSummary)
        let comments = dto.comments?.map(toComment) ?? []
        let companions = dto.companions?.map(toUserSummary) ?? []
        let feedKind = PostFeedKind(rawValue: dto.feedKind ?? PostFeedKind.checkIn.rawValue) ?? .checkIn
        let mediaType = firstMediaItem?.mediaType
            ?? dto.mediaType.flatMap { PostMediaType(rawValue: $0) }
            ?? .image
        let billSplit = dto.billSplit.map(toBillSplit)
        let viewCount = dto.viewCount ?? 0
        let viewers = dto.viewers?.map(toUserSummary) ?? []
        let audience = dto.audience.map(toAudience) ?? .friends

        return Post(
            id: dto.id,
            author: author,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            caption: dto.caption,
            reactions: reactions,
            reactionCount: dto.reactionCount,
            reactorCount: dto.reactorCount,
            reactionPreview: serverPreview,
            comments: comments,
            commentCount: dto.commentCount,
            groupId: dto.groupId,
            companionGroupName: nil,
            createdAt: dto.createdAt,
            mediaType: mediaType,
            videoURL: videoURL,
            videoDurationSeconds: dto.videoDurationSeconds ?? firstMediaItem?.durationSeconds,
            mediaItems: mappedMediaItems,
            companions: companions,
            feedKind: feedKind,
            checkInPlace: dto.location?.displayName ?? dto.checkInPlace,
            billSplit: billSplit,
            viewCount: viewCount,
            viewers: viewers,
            audience: audience,
            editedAt: dto.editedAt
        )
    }

    static func toEditRevision(_ dto: PostEditRevisionDTO) -> PostEditRevision {
        PostEditRevision(
            editedAt: dto.editedAt,
            caption: dto.caption,
            mediaItems: dto.mediaItems.compactMap(toMediaItem)
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
            widthPx: dto.widthPx,
            heightPx: dto.heightPx,
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
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            deletedAt: dto.deletedAt,
            commentType: CommentType(rawValue: dto.commentType ?? CommentType.standard.rawValue) ?? .standard,
            evidenceId: dto.evidenceId,
            splitId: dto.splitId,
            evidenceStatus: dto.evidenceStatus.flatMap { EvidenceStatus(rawValue: $0) }
        )
    }

    static func toCommentThreadPage(_ dto: CommentThreadPageDTO) -> CommentThreadPage {
        CommentThreadPage(
            comments: dto.comments.map(toComment),
            page: dto.page,
            limit: dto.limit,
            hasMore: dto.hasMore
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

    static func toReactionUserSummary(_ dto: ReactionUserSummaryDTO) -> UserReactionSummary {
        UserReactionSummary(
            user: toUserSummary(dto.user),
            emojiCounts: dto.emojiCounts.map { UserEmojiCount(emoji: $0.emoji, count: $0.count) }
        )
    }

    static func toPostReactions(_ dto: PostReactionsDTO) -> (
        reactionCount: Int,
        reactorCount: Int,
        items: [UserReactionSummary]
    ) {
        (
            dto.reactionCount,
            dto.reactorCount,
            dto.items.map(toReactionUserSummary)
        )
    }

    static func toAlbumPhoto(_ dto: AlbumPhotoDTO) -> AlbumPhoto? {
        guard let mediaURL = URL(string: dto.mediaUrl) else { return nil }
        let mediaType = PostMediaType(rawValue: dto.mediaType.lowercased()) ?? .image
        return AlbumPhoto(
            id: dto.mediaItemId,
            postId: dto.postId,
            author: toUserSummary(dto.author),
            groupId: dto.groupId,
            caption: dto.caption,
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
            avatarURL: dto.avatarUrl.flatMap(URL.init(string:)),
            viewedAt: dto.viewedAt
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

    static func toAudience(_ dto: PostAudienceDTO) -> PostAudience {
        PostAudience(
            mode: PostAudienceMode(rawValue: dto.mode?.lowercased() ?? "") ?? .friends,
            allowedGroupIds: dto.allowedGroupIds ?? [],
            allowedUserIds: dto.allowedUserIds ?? [],
            excludedUserIds: dto.excludedUserIds ?? []
        )
    }

    static func toStreakSummary(_ dto: StreakSummaryDTO) -> StreakSummary {
        StreakSummary(currentStreak: dto.currentStreak, hasTodayPhoto: dto.hasTodayPhoto)
    }

    static func toStreakDay(_ dto: StreakDayDTO) -> StreakDay? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let date = formatter.date(from: dto.date) else { return nil }
        return StreakDay(
            date: date,
            firstPhotoURL: dto.firstPhotoUrl.flatMap(URL.init(string:)),
            firstThumbnailURL: dto.firstThumbnailUrl.flatMap(URL.init(string:)),
            photoCount: dto.photoCount
        )
    }

    private static func toBillSplitLine(_ line: PostBillSplitLineDTO) -> PostBillSplitLine {
        let amount = Decimal(string: line.amount) ?? 0
        let paymentStatus = line.paymentStatus.flatMap { PaymentSplitStatus(rawValue: $0) }
        return PostBillSplitLine(
            id: line.id ?? UUID(),
            user: toUserSummary(line.user),
            amount: amount,
            isPaid: line.isPaid ?? false,
            paymentStatus: paymentStatus,
            latestEvidenceCommentId: line.latestEvidenceCommentId,
            lastRejectedAt: line.lastRejectedAt,
            reminderCount: line.reminderCount ?? 0
        )
    }

    static func toPlace(_ dto: PostLocationDTO) -> PostPlace? {
        let name = dto.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { return nil }
        return PostPlace(placeId: dto.placeId, displayName: name, lat: dto.lat, lon: dto.lon)
    }
}
