import Foundation
import SwiftUI
import Common
import Localization
import SplickDomain

@MainActor
public final class NotificationListViewModel: ObservableObject {
    static let pageSize = 20

    @Published var notifications: [AppNotification] = []
    @Published var state: LoadingState<[AppNotification]> = .idle
    @Published var selectedCategory: NotificationListCategory = .all
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMorePages = true

    private let fetchNotificationsUseCase: FetchNotificationsUseCaseProtocol
    private let markReadUseCase: MarkNotificationReadUseCaseProtocol
    private let markClickedUseCase: MarkNotificationClickedUseCaseProtocol
    private let languageService: LanguageService
    private let onBadgeCountsChanged: (() async -> Void)?
    private var currentPage = 0
    private var pullToRefreshTask: Task<Void, Never>?

    public init(
        fetchNotificationsUseCase: FetchNotificationsUseCaseProtocol,
        markReadUseCase: MarkNotificationReadUseCaseProtocol,
        markClickedUseCase: MarkNotificationClickedUseCaseProtocol,
        languageService: LanguageService,
        onBadgeCountsChanged: (() async -> Void)? = nil
    ) {
        self.fetchNotificationsUseCase = fetchNotificationsUseCase
        self.markReadUseCase = markReadUseCase
        self.markClickedUseCase = markClickedUseCase
        self.languageService = languageService
        self.onBadgeCountsChanged = onBadgeCountsChanged
    }

    var showsInitialLoading: Bool {
        notifications.isEmpty && state.isLoading
    }

    var notificationSections: [NotificationListSection] {
        NotificationListSection.grouped(from: notifications)
    }

    func selectCategory(_ category: NotificationListCategory) async {
        guard category != selectedCategory else { return }
        selectedCategory = category
        notifications = []
        await load()
    }

    func load(isPullToRefresh: Bool = false) async {
        if isPullToRefresh {
            if let existing = pullToRefreshTask {
                await existing.value
                return
            }

            let task = Task { @MainActor in
                isRefreshing = true
                defer { isRefreshing = false }
                await performLoad(isPullToRefresh: true)
            }
            pullToRefreshTask = task
            await task.value
            pullToRefreshTask = nil
            return
        }

        if notifications.isEmpty {
            state = .loading
        }
        await performLoad(isPullToRefresh: false)
    }

    func loadMoreIfNeeded(current notification: AppNotification) async {
        guard notification.id == notifications.last?.id else { return }
        await loadMore()
    }

    func loadMore() async {
        guard hasMorePages, !isLoadingMore, !isRefreshing, !state.isLoading else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1
        Log.info(
            "Loading more notifications",
            category: .notification,
            metadata: ["page": String(nextPage)]
        )

        do {
            let batch = try await fetchNotificationsUseCase.execute(page: nextPage, category: selectedCategory)
            hasMorePages = batch.count >= Self.pageSize
            guard !batch.isEmpty else {
                hasMorePages = false
                return
            }
            currentPage = nextPage
            notifications.append(contentsOf: batch)
            state = .loaded(notifications)
        } catch {
            Log.error(error, category: .notification)
        }
    }

    private func performLoad(isPullToRefresh: Bool) async {
        currentPage = 0
        hasMorePages = true
        Log.info(
            "Loading notifications",
            category: .notification,
            metadata: ["pullToRefresh": String(isPullToRefresh)]
        )

        do {
            let batch = try await fetchNotificationsUseCase.execute(page: 0, category: selectedCategory)
            notifications = batch
            hasMorePages = batch.count >= Self.pageSize
            state = .loaded(batch)
            Log.info(
                "Loaded notifications",
                category: .notification,
                metadata: ["count": String(batch.count), "hasMore": String(hasMorePages)]
            )
        } catch {
            if isPullToRefresh, !notifications.isEmpty {
                Log.error(error, category: .notification)
                state = .loaded(notifications)
            } else {
                state = .failed(languageService.localizedMessage(for: error))
                Log.error(error, category: .notification)
            }
        }
    }

    func handleTap(_ notification: AppNotification) async -> NotificationNavigationTarget {
        let target = notification.navigationTarget

        if !notification.isRead {
            markLocalAsRead(notification)
        }

        do {
            try await markClickedUseCase.execute(id: notification.id)
            markLocalAsRead(notification)
            await onBadgeCountsChanged?()
        } catch {
            Log.error(error, category: .notification)
            if !notification.isRead {
                await markAsReadFallback(notification)
            }
        }

        return target
    }

    public func markMessageNotificationsRead(conversationId: UUID) async {
        let unreadMessageNotifications = notifications.filter {
            !$0.isRead
                && $0.type.isMessagingNotification
                && (
                    $0.destination?.conversationId == conversationId
                        || $0.referenceId == conversationId
                )
        }
        guard !unreadMessageNotifications.isEmpty else { return }

        for notification in unreadMessageNotifications {
            markLocalAsRead(notification)
        }

        for notification in unreadMessageNotifications {
            do {
                try await markReadUseCase.execute(id: notification.id)
            } catch {
                Log.error(error, category: .notification)
            }
        }

        await onBadgeCountsChanged?()
    }

    public func markAllAsRead() async {
        do {
            try await markReadUseCase.markAllRead()
            notifications = notifications.map { $0.markingAsRead() }
            await onBadgeCountsChanged?()
        } catch {
            Log.error(error, category: .notification)
        }
    }

    public var unreadCount: Int {
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
            await onBadgeCountsChanged?()
        } catch {
            Log.error(error, category: .notification)
        }
    }
}
