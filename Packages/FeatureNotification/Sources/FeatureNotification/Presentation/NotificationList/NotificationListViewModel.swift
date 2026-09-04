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
    private let onMarkAllReadCompleted: (() async -> Void)?
    private var currentPage = 0
    private var pullToRefreshTask: Task<Void, Never>?

    @Published private(set) var friendRequestOutcomes: [UUID: FriendRequestInboxOutcome] = [:]
    @Published private(set) var processingFriendRequestIds: Set<UUID> = []
    @Published var friendRequestAlertMessage: String?
    @Published private var pendingIncomingFriendRequests: PendingIncomingFriendRequests?
    @Published private var staleFriendRequestIds: Set<UUID> = []

    public init(
        fetchNotificationsUseCase: FetchNotificationsUseCaseProtocol,
        markReadUseCase: MarkNotificationReadUseCaseProtocol,
        markClickedUseCase: MarkNotificationClickedUseCaseProtocol,
        markInboxSeenUseCase: MarkInboxSeenUseCaseProtocol,
        languageService: LanguageService,
        friendRequestInbox: FriendRequestInboxResponding? = nil,
        userDefaultsService: UserDefaultsServiceProtocol? = nil,
        onBadgeCountsChanged: (() async -> Void)? = nil,
        onMarkAllReadCompleted: (() async -> Void)? = nil
    ) {
        self.fetchNotificationsUseCase = fetchNotificationsUseCase
        self.markReadUseCase = markReadUseCase
        self.markClickedUseCase = markClickedUseCase
        self.markInboxSeenUseCase = markInboxSeenUseCase
        self.friendRequestInbox = friendRequestInbox
        self.userDefaultsService = userDefaultsService
        self.languageService = languageService
        self.onBadgeCountsChanged = onBadgeCountsChanged
        self.onMarkAllReadCompleted = onMarkAllReadCompleted
        friendRequestOutcomes = FriendRequestInboxOutcomePersistence.load(from: userDefaultsService)
    }

    var showsInitialLoading: Bool {
        notifications.isEmpty && state.isLoading
    }

    var notificationSections: [NotificationListSection] {
        NotificationListSection.grouped(from: notifications)
    }

    func selectCategory(_ category: NotificationListCategory) async {
        guard category != .all else { return }
        pullToRefreshTask?.cancel()
        pullToRefreshTask = nil
        let nextCategory: NotificationListCategory = selectedCategory == category ? .all : category
        guard nextCategory != selectedCategory else { return }
        selectedCategory = nextCategory
        notifications = []
        await load()
    }

    /// Fetches page 0 from the API when the inbox opens or the filter changes.
    public func reloadOnOpen() async {
        if notifications.isEmpty {
            await load()
        } else {
            await load(isPullToRefresh: true)
        }
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
            await refreshPendingIncomingFriendRequests()
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
            await refreshPendingIncomingFriendRequests()
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
            if let onMarkAllReadCompleted {
                await onMarkAllReadCompleted()
            } else {
                await onBadgeCountsChanged?()
            }
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

    func showsFriendRequestActions(for notification: AppNotification) -> Bool {
        FriendRequestInboxActionPolicy.shouldShowRespondActions(
            for: notification,
            hasStoredOutcome: friendRequestOutcome(for: notification) != nil,
            pendingIncoming: pendingIncomingFriendRequests,
            staleRequestIds: staleFriendRequestIds
        )
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
        guard showsFriendRequestActions(for: notification),
              let requestId = friendRequestId(for: notification),
              friendRequestInbox != nil,
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
            await refreshPendingIncomingFriendRequests()
            if !notification.isRead {
                markLocalAsRead(notification)
                try? await markReadUseCase.execute(id: notification.id)
                await onBadgeCountsChanged?()
            }
        } catch {
            Log.error(error, category: .notification)
            if isStaleFriendRequestError(error) {
                staleFriendRequestIds.insert(requestId)
                staleFriendRequestIds.insert(notification.id)
                return
            }
            friendRequestAlertMessage = languageService.localizedMessage(for: error)
        }
    }

    private func friendRequestId(for notification: AppNotification) -> UUID? {
        if let requestId = notification.referenceId { return requestId }
        if let actorId = notification.actorUserId {
            return pendingIncomingFriendRequests?.requestIdByRequester[actorId]
        }
        return nil
    }

    private func refreshPendingIncomingFriendRequests() async {
        guard let friendRequestInbox else { return }
        do {
            let pending = try await friendRequestInbox.pendingIncomingRequests()
            pendingIncomingFriendRequests = pending
            staleFriendRequestIds.subtract(pending.requestIds)
        } catch {
            Log.error(error, category: .notification)
        }
    }

    private func isStaleFriendRequestError(_ error: Error) -> Bool {
        let network = (error as? AppError).flatMap { appError -> NetworkError? in
            if case .network(let networkError) = appError { return networkError }
            return nil
        } ?? error as? NetworkError

        switch network {
        case .notFound:
            return true
        case .apiError(let code, let message, _):
            return isStaleFriendRequestText(code) || isStaleFriendRequestText(message)
        case .unknown(let message, _):
            return isStaleFriendRequestText(message)
        default:
            return isStaleFriendRequestText(error.localizedDescription)
        }
    }

    private func isStaleFriendRequestText(_ value: String) -> Bool {
        let normalized = value.lowercased()
        return normalized.contains("not_found")
            || normalized.contains("not found")
            || normalized.contains("conflict")
            || normalized.contains("already")
    }

    private func persistOutcome(_ requestId: UUID, _ outcome: FriendRequestInboxOutcome) {
        friendRequestOutcomes[requestId] = outcome
        FriendRequestInboxOutcomePersistence.save(friendRequestOutcomes, to: userDefaultsService)
    }
}
