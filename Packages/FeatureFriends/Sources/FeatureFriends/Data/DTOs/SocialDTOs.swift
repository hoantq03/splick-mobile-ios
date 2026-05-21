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
