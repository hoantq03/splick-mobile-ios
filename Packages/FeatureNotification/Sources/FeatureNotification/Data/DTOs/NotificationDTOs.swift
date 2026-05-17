import Foundation

struct NotificationResponseDTO: Decodable {
    let id: UUID
    let type: String
    let title: String
    let body: String
    let isRead: Bool
    let referenceId: UUID?
    let createdAt: Date
}

struct UnreadCountDTO: Decodable {
    let count: Int
}
