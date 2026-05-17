import Foundation
import SplickDomain

enum NotificationMapper {
    static func toNotification(_ dto: NotificationResponseDTO) -> AppNotification {
        AppNotification(
            id: dto.id,
            type: NotificationType(rawValue: dto.type) ?? .system,
            title: dto.title,
            body: dto.body,
            isRead: dto.isRead,
            referenceId: dto.referenceId,
            createdAt: dto.createdAt
        )
    }
}
