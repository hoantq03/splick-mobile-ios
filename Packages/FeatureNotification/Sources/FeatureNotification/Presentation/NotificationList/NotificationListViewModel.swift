import Foundation
import SwiftUI
import Common
import Localization
import SplickDomain
import Storage

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
    private let markInboxSeenUseCase: MarkInboxSeenUseCaseProtocol
    private let friendRequestInbox: FriendRequestInboxResponding?
    private let userDefaultsService: UserDefaultsServiceProtocol?
    private let languageService: LanguageService
    private let onBadgeCountsChanged: (() async -> Void)?
    private var currentPage = 0
    private var pullToRefreshTask: Task<Void, Never>?

    @Published private(set) var friendRequestOutcomes: [UUID: FriendRequestInboxOutcome] = [:]
    @Published private(set) var processingFriendRequestIds: Set<UUID> = []
    @Published var friendRequestAlertMessage: String?

    public init(
        fetchNotificationsUseCase: FetchNotificationsUseCaseProtocol,
        markReadUseCase: MarkNotificationReadUseCaseProtocol,
        markClickedUseCase: MarkNotificationClickedUseCaseProtocol,
        markInboxSeenUseCase: MarkInboxSeenUseCaseProtocol,
        languageService: LanguageService,
        friendRequestInbox: FriendRequestInboxResponding? = nil,
        userDefaultsService: UserDefaultsServiceProtocol? = nil,
        onBadgeCountsChanged: (() async -> Void)? = nil
    ) {
        self.fetchNotificationsUseCase = fetchNotificationsUseCase
        self.markReadUseCase = markReadUseCase
        self.markClickedUseCase = markClickedUseCase
        self.markInboxSeenUseCase = markInboxSeenUseCase
        self.friendRequestInbox = friendRequestInbox
        self.userDefaultsService = userDefaultsService
        self.languageService = languageService
        self.onBadgeCountsChanged = onBadgeCountsChanged
        friendRequestOutcomes = FriendRequestInboxOutcomePersistence.load(from: userDefaultsService)
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

        let category = selectedCategory
        do {
            let batch = try await fetchNotificationsUseCase.execute(page: nextPage, category: category)
            guard selectedCategory == category else { return }
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
        let category = selectedCategory
        currentPage = 0
        hasMorePages = true
        Log.info(
            "Loading notifications",
            category: .notification,
            metadata: [
                "pullToRefresh": String(isPullToRefresh),
                "filter": selectedCategory.queryValue ?? "ALL",
            ]
        )

        do {
            let batch = try await fetchNotificationsUseCase.execute(page: 0, category: category)
            guard selectedCategory == category else { return }
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

    public func markInboxSeen() async {
        do {
            try await markInboxSeenUseCase.execute()
            await onBadgeCountsChanged?()
        } catch {
            Log.error(error, category: .notification, metadata: ["action": "markInboxSeen"])
            await onBadgeCountsChanged?()
        }
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

    func reloadFriendRequestOutcomes() {
        let stored = FriendRequestInboxOutcomePersistence.load(from: userDefaultsService)
        friendRequestOutcomes.merge(stored) { _, current in current }
    }

    func friendRequestOutcome(for notification: AppNotification) -> FriendRequestInboxOutcome? {
        guard let requestId = notification.referenceId else { return nil }
        return friendRequestOutcomes[requestId]
    }

    func isProcessingFriendRequest(_ notification: AppNotification) -> Bool {
        guard let requestId = notification.referenceId else { return false }
        return processingFriendRequestIds.contains(requestId)
    }

    func acceptFriendRequest(_ notification: AppNotification) async {
        await respondToFriendRequest(notification, accept: true)
    }

    func rejectFriendRequest(_ notification: AppNotification) async {
        await respondToFriendRequest(notification, accept: false)
    }

    private func respondToFriendRequest(_ notification: AppNotification, accept: Bool) async {
        guard notification.canRespondToFriendRequest,
              let requestId = notification.referenceId,
              friendRequestInbox != nil,
              friendRequestOutcomes[requestId] == nil,
              !processingFriendRequestIds.contains(requestId)
        else { return }

        processingFriendRequestIds.insert(requestId)
        defer { processingFriendRequestIds.remove(requestId) }

        do {
            if accept {
                try await friendRequestInbox?.acceptIncomingRequest(requestId: requestId)
            } else {
                try await friendRequestInbox?.rejectIncomingRequest(requestId: requestId)
            }
            persistOutcome(requestId, accept ? .accepted : .rejected)
            if !notification.isRead {
                markLocalAsRead(notification)
                try? await markReadUseCase.execute(id: notification.id)
                await onBadgeCountsChanged?()
            }
        } catch {
            Log.error(error, category: .notification)
            friendRequestAlertMessage = languageService.localizedMessage(for: error)
        }
    }

    private func persistOutcome(_ requestId: UUID, _ outcome: FriendRequestInboxOutcome) {
        friendRequestOutcomes[requestId] = outcome
        FriendRequestInboxOutcomePersistence.save(friendRequestOutcomes, to: userDefaultsService)
    }
}
