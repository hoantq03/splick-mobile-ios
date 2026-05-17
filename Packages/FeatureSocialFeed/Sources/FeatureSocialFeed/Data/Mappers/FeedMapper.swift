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
            createdAt: dto.createdAt
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
}
