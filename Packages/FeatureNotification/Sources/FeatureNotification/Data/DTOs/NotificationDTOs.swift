import Foundation

struct NotificationDestinationDTO: Decodable {
    let screen: String
    let postId: UUID?
    let commentId: UUID?
}

struct NotificationResponseDTO: Decodable {
    let id: UUID
    let type: String
    let title: String
    let body: String
    let isRead: Bool
    let referenceId: UUID?
    let actorUserId: UUID?
    let actorAvatarUrl: String?
    let destination: NotificationDestinationDTO?
    let createdAt: Date
}

struct UnreadCountDTO: Decodable {
    let count: Int
}

struct BadgeCountsDTO: Decodable {
    let notifications: Int
    let friends: Int
    let expenses: Int
    let messages: Int
}
