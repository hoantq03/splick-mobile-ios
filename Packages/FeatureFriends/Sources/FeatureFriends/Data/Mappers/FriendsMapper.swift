import Foundation
import SplickDomain

enum FriendsMapper {
    static func toUserSearchResult(_ dto: UserSearchResponseDTO) -> UserSearchResult {
        UserSearchResult(
            user: toUserSummary(dto),
            friendStatus: mapFriendStatus(dto.friendStatus)
        )
    }

    static func toUserSummary(_ dto: UserSearchResponseDTO) -> UserSummary {
        UserSummary(
            id: dto.userId,
            username: dto.username,
            displayName: dto.displayName,
            avatarURL: dto.avatarUrl.flatMap { URL(string: $0) }
        )
    }

    static func mapFriendStatus(_ raw: String?) -> FriendRelationStatus {
        guard let raw, let status = FriendRelationStatus(rawValue: raw) else {
            return .none
        }
        return status
    }
}
