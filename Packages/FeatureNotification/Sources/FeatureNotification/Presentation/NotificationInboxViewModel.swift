import Foundation
import Combine
import SplickDomain

@MainActor
public class NotificationInboxViewModel: ObservableObject {
    @Published public var notifications: [AppNotification] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    private let repository: NotificationRepositoryProtocol
    
    public init(repository: NotificationRepositoryProtocol) {
        self.repository = repository
    }
    
    public func fetchNotifications() async {
        isLoading = true
        do {
            notifications = try await repository.fetchNotifications(page: 0, limit: 20)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    public func markAsClicked(notification: AppNotification) async {
        guard !notification.isRead else { return }
        
        do {
            try await repository.markAsRead(id: notification.id)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                let updated = AppNotification(
                    id: notification.id,
                    type: notification.type,
                    title: notification.title,
                    body: notification.body,
                    isRead: true,
                    referenceId: notification.referenceId,
                    createdAt: notification.createdAt
                )
                notifications[index] = updated
            }
        } catch {
            print("Failed to mark notification as read: \(error)")
        }
    }
}
