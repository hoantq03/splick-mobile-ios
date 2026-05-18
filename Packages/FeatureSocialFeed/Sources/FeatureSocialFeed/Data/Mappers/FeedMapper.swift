import Foundation
import SplickDomain

enum FeedMapper {
    static func toPost(_ dto: PostDTO) -> Post {
        Post(
            id: dto.id,
            author: toUserSummary(dto.author),
            imageURL: URL(string: dto.imageUrl)!,
            thumbnailURL: dto.thumbnailUrl.flatMap(URL.init(string:)),
            caption: dto.caption,
            reactions: dto.reactions.map(toReaction),
            groupId: dto.groupId,
            createdAt: dto.createdAt,
            mediaType: dto.mediaType.flatMap { PostMediaType(rawValue: $0) } ?? .image,
            videoURL: dto.videoUrl.flatMap(URL.init(string:)),
            videoDurationSeconds: dto.videoDurationSeconds,
            companions: dto.companions?.map(toUserSummary) ?? [],
            feedKind: PostFeedKind(rawValue: dto.feedKind ?? PostFeedKind.checkIn.rawValue) ?? .checkIn,
            checkInPlace: dto.checkInPlace,
            billSplit: dto.billSplit.map(toBillSplit),
            viewCount: dto.viewCount ?? 0
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
        PostBillSplit(
            totalAmount: dto.totalAmount,
            currency: dto.currency,
            splits: dto.splits.map { line in
                PostBillSplitLine(
                    id: line.id ?? UUID(),
                    user: toUserSummary(line.user),
                    amount: line.amount
                )
            }
        )
    }
}
