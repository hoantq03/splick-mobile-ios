import Foundation

struct UserSearchResponseDTO: Decodable {
    let userId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let friendStatus: String?
}

struct SocialPageMetaDTO: Decodable {
    let page: Int
    let size: Int
    let totalElements: Int
    let totalPages: Int
}

struct SocialPageUserSearchResponseDTO: Decodable {
    let content: [UserSearchResponseDTO]
    let page: SocialPageMetaDTO
}

struct MyQRResponseDTO: Decodable {
    let payload: String
    let version: Int
    let issuedAt: Date
}

struct SendFriendRequestBodyDTO: Encodable {
    let username: String
    let message: String?
}

struct FriendRequestResponseDTO: Decodable {
    let id: UUID
    let requesterId: UUID
    let addresseeId: UUID
    let status: String
    let message: String?
    let createdAt: Date
    let expiresAt: Date
}

struct IncomingFriendRequestResponseDTO: Decodable {
    let id: UUID
    let requesterId: UUID
    let requesterUsername: String
    let requesterDisplayName: String
    let requesterAvatarUrl: String?
    let message: String?
    let createdAt: Date
    let expiresAt: Date
}

struct SocialPageIncomingFriendRequestResponseDTO: Decodable {
    let content: [IncomingFriendRequestResponseDTO]
    let page: SocialPageMetaDTO
}

struct FriendshipResponseDTO: Decodable {
    let friendshipId: UUID
    let userAId: UUID
    let userBId: UUID
    let createdAt: Date
}

struct FriendResponseDTO: Decodable {
    let friendId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let nickname: String?
    let friendsSince: Date
}

struct SocialPageFriendResponseDTO: Decodable {
    let content: [FriendResponseDTO]
    let page: SocialPageMetaDTO
}

struct GroupResponseDTO: Decodable {
    let id: UUID
    let name: String
    let description: String?
    let avatarUrl: String?
    let ownerId: UUID
    let createdAt: Date
}

struct GroupSummaryResponseDTO: Decodable {
    let id: UUID
    let name: String
    let avatarUrl: String?
    let ownerId: UUID
    let createdAt: Date
    let memberCount: Int
}

struct SocialPageGroupSummaryResponseDTO: Decodable {
    let content: [GroupSummaryResponseDTO]
    let page: SocialPageMetaDTO
}

struct CreateGroupBodyDTO: Encodable {
    let name: String
    let description: String?
}

struct InviteCodeResponseDTO: Decodable {
    let id: UUID
    let code: String
    let groupId: UUID
    let issuedAt: Date
    let expiresAt: Date?
    let maxUses: Int?
    let usedCount: Int
}

struct InviteFriendsBodyDTO: Encodable {
    let userIds: [UUID]
}

struct InviteFriendsResponseDTO: Decodable {
    let invited: [UUID]
    let skipped: [UUID]
}

struct MemberResponseDTO: Decodable {
    let id: UUID
    let userId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let role: String?
    let status: String?
}

struct SocialPageMemberResponseDTO: Decodable {
    let content: [MemberResponseDTO]
    let page: SocialPageMetaDTO
}
