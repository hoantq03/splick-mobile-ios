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
