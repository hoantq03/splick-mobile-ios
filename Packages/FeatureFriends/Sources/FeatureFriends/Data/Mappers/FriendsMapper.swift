import Foundation
import SplickDomain

enum FriendsMapper {
    static func toUserSummary(_ dto: UserSearchResponseDTO) -> UserSummary {
        UserSummary(
            id: dto.userId,
            username: dto.username,
            displayName: dto.displayName,
            avatarURL: dto.avatarUrl.flatMap { URL(string: $0) }
        )
    }
}
