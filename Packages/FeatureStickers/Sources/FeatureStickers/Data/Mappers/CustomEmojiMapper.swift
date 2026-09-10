import Foundation
import SplickDomain

enum CustomEmojiMapper {
    static func toDomain(_ dto: CustomEmojiResponseDTO) -> CustomEmoji? {
        guard let url = URL(string: dto.mediaUrl) else { return nil }
        return CustomEmoji(
            id: dto.id,
            ownerId: dto.ownerId,
            shortcode: dto.shortcode,
            mediaUrl: url,
            createdAt: dto.createdAt
        )
    }
}
