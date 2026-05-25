import Foundation

public struct NotificationItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let eventId: String
    public let type: String
    public let message: String
    public let createdAt: Date
    public let readAt: Date?
    public let clickedAt: Date?
    
    public init(id: UUID, eventId: String, type: String, message: String, createdAt: Date, readAt: Date? = nil, clickedAt: Date? = nil) {
        self.id = id
        self.eventId = eventId
        self.type = type
        self.message = message
        self.createdAt = createdAt
        self.readAt = readAt
        self.clickedAt = clickedAt
    }
}
