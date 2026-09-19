import Foundation

struct UserProfileStatsResponseDTO: Decodable {
    let friendCount: Int
    let postCount: Int
    let groupCount: Int
}

struct UserProfileResponseDTO: Decodable {
    let userId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let nickname: String?
    let subtitle: String?
    let friendStatus: String?
    let stats: UserProfileStatsResponseDTO
    let online: Bool?
    let lastSeenAt: Date?
}

struct PaymentProfileResponseDTO: Decodable {
    let userId: UUID
    let qrImageUrl: String?
    let accountName: String?
    let accountNumber: String?
    let bankName: String?
    let updatedAt: Date
}

struct UserSearchResponseDTO: Decodable {
    let userId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let friendStatus: String?
    let distanceMeters: Int?
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
    let addresseeUsername: String?
    let addresseeDisplayName: String?
}

struct SendFriendRequestByQrBodyDTO: Encodable {
    let qrPayload: String
    let message: String?
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

struct SocialPageFriendRequestResponseDTO: Decodable {
    let content: [FriendRequestResponseDTO]
    let page: SocialPageMetaDTO
}

struct SetNicknameBodyDTO: Encodable {
    let nickname: String?
}

struct BlockUserBodyDTO: Encodable {
    let userId: UUID
}

struct BlockedUserResponseDTO: Decodable {
    let userId: UUID
    let username: String
    let displayName: String
    let blockedAt: Date
}

struct SocialPageBlockedUserResponseDTO: Decodable {
    let content: [BlockedUserResponseDTO]
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
    let online: Bool?
    let lastSeenAt: Date?
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

struct JoinGroupByCodeBodyDTO: Encodable {
    let code: String
}

struct JoinGroupByQRBodyDTO: Encodable {
    let qrPayload: String
}

struct JoinGroupResponseDTO: Decodable {
    let groupId: UUID
    let membershipId: UUID
    let status: String
}

struct UpdateGroupBodyDTO: Encodable {
    let name: String
    let description: String?
}

struct UpdateAvatarBodyDTO: Encodable {
    let avatarUrl: String
}

struct TransferOwnershipBodyDTO: Encodable {
    let newOwnerId: UUID
}

struct GenerateGroupQRBodyDTO: Encodable {
    let ttlSeconds: Int?
}

struct GroupQRResponseDTO: Decodable {
    let id: UUID
    let payload: String
    let groupId: UUID
    let issuedAt: Date
    let expiresAt: Date
}

struct BulkPresenceRequestDTO: Encodable {
    let userIds: [UUID]
}

struct PresenceSnapshotDTO: Decodable {
    let userId: UUID
    let online: Bool
    let lastSeenAt: Date?
}

struct BulkPresenceResponseDTO: Decodable {
    let items: [PresenceSnapshotDTO]
}

struct NearbyUsersBodyDTO: Encodable {
    let lat: Double
    let lon: Double
}

struct UpdateDiscoveryPreferenceBodyDTO: Encodable {
    let nearbyEnabled: Bool
}

struct DiscoveryPreferenceResponseDTO: Decodable {
    let nearbyEnabled: Bool
}
