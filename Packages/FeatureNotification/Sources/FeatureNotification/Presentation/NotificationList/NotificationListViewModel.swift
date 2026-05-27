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
    private let markClickedUseCase: MarkNotificationClickedUseCaseProtocol
    private var currentPage = 0

    public init(
        fetchNotificationsUseCase: FetchNotificationsUseCaseProtocol,
        markReadUseCase: MarkNotificationReadUseCaseProtocol,
        markClickedUseCase: MarkNotificationClickedUseCaseProtocol
    ) {
        self.fetchNotificationsUseCase = fetchNotificationsUseCase
        self.markReadUseCase = markReadUseCase
        self.markClickedUseCase = markClickedUseCase
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

    func handleTap(_ notification: AppNotification) async -> UUID? {
        let postId = notification.postNavigationId

        do {
            try await markClickedUseCase.execute(id: notification.id)
            markLocalAsRead(notification)
        } catch {
            Log.error(error, category: .notification)
            if !notification.isRead {
                await markAsReadFallback(notification)
            }
        }

        return postId
    }

    func markAllAsRead() async {
        do {
            try await markReadUseCase.markAllRead()
            notifications = notifications.map { $0.markingAsRead() }
        } catch {
            Log.error(error, category: .notification)
        }
    }

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    private func markLocalAsRead(_ notification: AppNotification) {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index] = notification.markingAsRead()
    }

    private func markAsReadFallback(_ notification: AppNotification) async {
        do {
            try await markReadUseCase.execute(id: notification.id)
            markLocalAsRead(notification)
        } catch {
            Log.error(error, category: .notification)
        }
    }
}
