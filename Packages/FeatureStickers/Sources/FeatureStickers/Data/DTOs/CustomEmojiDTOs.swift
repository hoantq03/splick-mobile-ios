import Foundation

struct CustomEmojiResponseDTO: Decodable {
    let id: UUID
    let ownerId: UUID?
    let shortcode: String
    let mediaUrl: String
    let createdAt: Date
}

struct CreateCustomEmojiRequestDTO: Encodable {
    let alias: String?
    let mediaId: UUID
}
