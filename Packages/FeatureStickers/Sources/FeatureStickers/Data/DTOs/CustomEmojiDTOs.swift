import Foundation

struct CustomEmojiResponseDTO: Decodable {
    let id: UUID
    let shortcode: String
    let mediaUrl: String
    let createdBy: UUID?
    let createdAt: Date
}

struct CreateCustomEmojiRequestDTO: Encodable {
    let shortcode: String
    let mediaId: UUID
}
