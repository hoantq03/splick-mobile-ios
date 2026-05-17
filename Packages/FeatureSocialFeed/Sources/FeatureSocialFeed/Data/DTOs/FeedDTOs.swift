import Foundation

struct PostDTO: Decodable {
    let id: UUID
    let author: AuthorDTO
    let imageUrl: String
    let thumbnailUrl: String?
    let caption: String?
    let reactions: [ReactionDTO]
    let groupId: UUID?
    let createdAt: Date
}

struct AuthorDTO: Decodable {
    let id: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
}

struct ReactionDTO: Decodable {
    let id: UUID
    let emoji: String
    let userId: UUID
    let createdAt: Date
}

struct CreateReactionRequestDTO: Encodable {
    let emoji: String
}

struct CreatePostRequestDTO: Encodable {
    let caption: String?
    let groupId: UUID?
}
