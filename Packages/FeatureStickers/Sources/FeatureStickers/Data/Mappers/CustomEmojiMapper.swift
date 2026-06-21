import Foundation
import SplickDomain

enum CustomEmojiMapper {
    static func toDomain(_ dto: CustomEmojiResponseDTO, groupId: UUID) -> CustomEmoji? {
        guard let url = URL(string: dto.mediaUrl) else { return nil }
        return CustomEmoji(
            id: dto.id,
            groupId: groupId,
            shortcode: dto.shortcode,
            mediaUrl: url,
            createdBy: dto.createdBy,
            createdAt: dto.createdAt
        )
    }
}
