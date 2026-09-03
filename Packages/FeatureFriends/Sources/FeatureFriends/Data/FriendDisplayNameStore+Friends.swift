import Common
import SplickDomain

extension FriendDisplayNameStore {
    func resolve(_ member: GroupMemberItem) -> GroupMemberItem {
        let resolved = resolve(
            UserSummary(
                id: member.userId,
                username: member.username,
                displayName: member.displayName,
                avatarURL: member.avatarURL
            )
        )
        return GroupMemberItem(
            id: member.id,
            userId: member.userId,
            username: member.username,
            displayName: resolved.displayName,
            avatarURL: member.avatarURL,
            role: member.role,
            status: member.status
        )
    }

    func resolve(_ members: [GroupMemberItem]) -> [GroupMemberItem] {
        members.map(resolve)
    }

    func resolve(_ result: UserSearchResult) -> UserSearchResult {
        UserSearchResult(
            user: resolve(result.user),
            friendStatus: result.friendStatus,
            distanceMeters: result.distanceMeters
        )
    }

    func resolve(_ results: [UserSearchResult]) -> [UserSearchResult] {
        results.map(resolve)
    }
}
