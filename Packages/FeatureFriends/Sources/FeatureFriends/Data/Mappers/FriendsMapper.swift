import Foundation
import SplickDomain

enum FriendsMapper {
    static func toUserSearchResult(_ dto: UserSearchResponseDTO) -> UserSearchResult {
        UserSearchResult(
            user: toUserSummary(dto),
            friendStatus: mapFriendStatus(dto.friendStatus)
        )
    }

    static func toUserSummary(_ dto: FriendResponseDTO) -> UserSummary {
        let label = (dto.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { nick in
            nick.isEmpty ? nil : nick
        } ?? dto.displayName
        return UserSummary(
            id: dto.friendId,
            username: dto.username,
            displayName: label,
            avatarURL: dto.avatarUrl.flatMap { URL(string: $0) }
        )
    }

    static func toOutgoingFriendRequest(_ dto: FriendRequestResponseDTO) -> OutgoingFriendRequest {
        let username = dto.addresseeUsername ?? "user"
        let displayName = dto.addresseeDisplayName ?? username
        return OutgoingFriendRequest(
            id: dto.id,
            addressee: UserSummary(
                id: dto.addresseeId,
                username: username,
                displayName: displayName,
                avatarURL: nil
            ),
            message: dto.message,
            createdAt: dto.createdAt,
            expiresAt: dto.expiresAt
        )
    }

    static func toBlockedUser(_ dto: BlockedUserResponseDTO) -> BlockedUser {
        BlockedUser(
            user: UserSummary(
                id: dto.userId,
                username: dto.username,
                displayName: dto.displayName,
                avatarURL: nil
            ),
            blockedAt: dto.blockedAt
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

    static func toIncomingFriendRequest(_ dto: IncomingFriendRequestResponseDTO) -> IncomingFriendRequest {
        IncomingFriendRequest(
            id: dto.id,
            requester: UserSummary(
                id: dto.requesterId,
                username: dto.requesterUsername,
                displayName: dto.requesterDisplayName,
                avatarURL: dto.requesterAvatarUrl.flatMap { URL(string: $0) }
            ),
            message: dto.message,
            createdAt: dto.createdAt,
            expiresAt: dto.expiresAt
        )
    }

    static func mapFriendStatus(_ raw: String?) -> FriendRelationStatus {
        guard let raw, let status = FriendRelationStatus(rawValue: raw) else {
            return .none
        }
        return status
    }

    static func toGroup(_ dto: GroupResponseDTO) -> Group {
        Group(
            id: dto.id,
            name: dto.name,
            inviteCode: "",
            description: dto.description,
            avatarURL: dto.avatarUrl.flatMap { URL(string: $0) },
            members: [],
            memberCount: 1,
            createdBy: dto.ownerId,
            createdAt: dto.createdAt
        )
    }

    static func toUserSummary(_ dto: MemberResponseDTO) -> UserSummary {
        UserSummary(
            id: dto.userId,
            username: dto.username,
            displayName: dto.displayName,
            avatarURL: dto.avatarUrl.flatMap { URL(string: $0) }
        )
    }

    static func toGroupInviteCode(_ dto: InviteCodeResponseDTO) -> GroupInviteCode {
        GroupInviteCode(
            id: dto.id,
            code: dto.code,
            groupId: dto.groupId,
            issuedAt: dto.issuedAt,
            expiresAt: dto.expiresAt
        )
    }

    static func toGroup(_ dto: GroupSummaryResponseDTO) -> Group {
        Group(
            id: dto.id,
            name: dto.name,
            inviteCode: "",
            description: nil,
            avatarURL: dto.avatarUrl.flatMap { URL(string: $0) },
            members: [],
            memberCount: dto.memberCount,
            createdBy: dto.ownerId,
            createdAt: dto.createdAt
        )
    }
}
