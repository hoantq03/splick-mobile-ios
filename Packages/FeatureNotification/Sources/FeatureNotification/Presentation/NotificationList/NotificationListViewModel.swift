import Foundation
import SwiftUI
import Common
import SplickDomain

@MainActor
public final class NotificationListViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var state: LoadingState<[AppNotification]> = .idle

    private let fetchNotificationsUseCase: FetchNotificationsUseCaseProtocol
    private let markReadUseCase: MarkNotificationReadUseCaseProtocol
    private var currentPage = 0

    public init(
        fetchNotificationsUseCase: FetchNotificationsUseCaseProtocol,
        markReadUseCase: MarkNotificationReadUseCaseProtocol
    ) {
        self.fetchNotificationsUseCase = fetchNotificationsUseCase
        self.markReadUseCase = markReadUseCase
    }

    func load() async {
        state = .loading
        currentPage = 0

        do {
            let notifications = try await fetchNotificationsUseCase.execute(page: 0)
            self.notifications = notifications
            state = .loaded(notifications)
        } catch {
            state = .failed(error.localizedDescription)
            Log.error(error, category: .notification)
        }
    }

    func markAsRead(_ notification: AppNotification) async {
        guard !notification.isRead else { return }

        do {
            try await markReadUseCase.execute(id: notification.id)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index] = AppNotification(
                    id: notification.id,
                    type: notification.type,
                    title: notification.title,
                    body: notification.body,
                    isRead: true,
                    referenceId: notification.referenceId,
                    createdAt: notification.createdAt
                )
            }
        } catch {
            Log.error(error, category: .notification)
        }
    }

    func markAllAsRead() async {
        do {
            try await markReadUseCase.markAllRead()
            notifications = notifications.map {
                AppNotification(
                    id: $0.id, type: $0.type, title: $0.title,
                    body: $0.body, isRead: true,
                    referenceId: $0.referenceId, createdAt: $0.createdAt
                )
            }
        } catch {
            Log.error(error, category: .notification)
        }
    }

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
}
