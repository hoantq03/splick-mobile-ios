import Foundation
import Combine

@MainActor
public class NotificationInboxViewModel: ObservableObject {
    @Published public var notifications: [NotificationItem] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    private let repository: NotificationRepository
    
    public init(repository: NotificationRepository) {
        self.repository = repository
    }
    
    public func fetchNotifications() async {
        isLoading = true
        do {
            notifications = try await repository.getNotifications(page: 0, limit: 20)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    public func markAsClicked(notification: NotificationItem) async {
        guard notification.clickedAt == nil else { return }
        
        do {
            try await repository.markAsClicked(id: notification.id)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                let updated = NotificationItem(
                    id: notification.id,
                    eventId: notification.eventId,
                    type: notification.type,
                    message: notification.message,
                    createdAt: notification.createdAt,
                    readAt: Date(), // implicitly read
                    clickedAt: Date()
                )
                notifications[index] = updated
            }
        } catch {
            print("Failed to mark notification as clicked: \(error)")
        }
    }
}
