import Foundation
import SplickDomain
import SplickWidgetKit
import FeatureExpense
import FeatureMessaging
import FeatureFriends
import FeatureSocialFeed

@MainActor
final class WidgetSyncBridge {
    private let syncService: WidgetDataSyncService
    private let fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol
    private let fetchExpensesUseCase: FetchExpensesUseCaseProtocol
    private let fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol

    /// Opening Friends reloads the group directory often — don't refetch widget expenses every time.
    private static let groupExpenseSyncInterval: TimeInterval = 10 * 60
    private var lastGroupExpenseSyncAt: Date?
    private var lastSyncedGroupIds: Set<UUID> = []
    private var groupExpenseSyncTask: Task<Void, Never>?

    init(
        syncService: WidgetDataSyncService = .shared,
        fetchIncomingFriendRequestsUseCase: FetchIncomingFriendRequestsUseCaseProtocol,
        fetchExpensesUseCase: FetchExpensesUseCaseProtocol,
        fetchDebtSummaryUseCase: FetchDebtSummaryUseCaseProtocol
    ) {
        self.syncService = syncService
        self.fetchIncomingFriendRequestsUseCase = fetchIncomingFriendRequestsUseCase
        self.fetchExpensesUseCase = fetchExpensesUseCase
        self.fetchDebtSummaryUseCase = fetchDebtSummaryUseCase
    }

    func syncExpenses(debts: [DebtSummary], expenses: [Expense], group: Group?, currentUserId: UUID?) {
        syncService.syncExpenseSummary(debts: debts)
        guard let group else { return }
        syncService.syncGroupExpense(
            group: group,
            expenses: expenses,
            debts: debts,
            currentUserId: currentUserId
        )
    }

    func syncGroups(_ groups: [Group]) {
        // Only persist the group directory for widgets. Do NOT fetch /expenses here —
        // Friends tab load calls this on every open and was spamming debts/expenses APIs.
        syncService.syncGroups(groups)
    }

    /// Refresh per-group expense snapshots for widgets (call from expenses tab, not Friends).
    func syncGroupExpensesIfStale(groups: [Group]) {
        Task {
            await syncGroupExpensesIfNeeded(for: groups)
        }
    }

    private func syncGroupExpensesIfNeeded(for groups: [Group]) async {
        let targets = Array(groups.prefix(5))
        guard !targets.isEmpty else { return }

        let groupIds = Set(targets.map(\.id))
        let groupsUnchanged = groupIds == lastSyncedGroupIds
        if groupsUnchanged,
           let lastGroupExpenseSyncAt,
           Date().timeIntervalSince(lastGroupExpenseSyncAt) < Self.groupExpenseSyncInterval {
            return
        }

        if let existing = groupExpenseSyncTask {
            await existing.value
            return
        }

        let task = Task { @MainActor in
            await syncGroupExpenses(for: targets)
            lastGroupExpenseSyncAt = Date()
            lastSyncedGroupIds = groupIds
        }
        groupExpenseSyncTask = task
        await task.value
        groupExpenseSyncTask = nil
    }

    private func syncGroupExpenses(for groups: [Group]) async {
        for group in groups {
            do {
                async let expensesTask = fetchExpensesUseCase.execute(groupId: group.id, page: 0)
                async let debtsTask = fetchDebtSummaryUseCase.execute(groupId: group.id)
                let (expenses, debts) = try await (expensesTask, debtsTask)
                syncService.syncGroupExpense(
                    group: group,
                    expenses: expenses,
                    debts: debts,
                    currentUserId: nil
                )
            } catch {
                continue
            }
        }
    }

    func syncConversations(_ conversations: [Conversation], totalUnreadCount: Int) {
        let unreadTotal = conversations.reduce(0) { $0 + $1.unreadCount }
        let total = max(totalUnreadCount, unreadTotal)
        let previews = conversations
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(5)
            .map { conversation in
                WidgetConversationPreviewInput(
                    id: conversation.id,
                    displayTitle: conversation.displayTitle,
                    previewText: messagePreview(for: conversation),
                    unreadCount: conversation.unreadCount,
                    avatarURL: avatarURL(for: conversation),
                    updatedAt: conversation.updatedAt
                )
            }

        syncService.syncMessagingInbox(
            conversations: Array(previews),
            totalUnreadCount: total
        )
    }

    func syncFeed(posts: [Post], currentUserId: UUID?) async {
        let latestFriendPost = posts.first { $0.author.id != currentUserId && $0.mediaType == .image }
        await syncService.syncLatestFriendPhoto(post: latestFriendPost, currentUserId: currentUserId)
    }

    func syncStreak(_ summary: StreakSummary) {
        syncService.syncStreak(summary)
    }

    func syncFriendRequests(_ requests: [IncomingFriendRequest]) {
        let previews = requests.map { request in
            WidgetFriendRequestPreviewInput(
                id: request.id,
                requesterName: request.requester.displayName,
                requesterUsername: request.requester.username,
                avatarURL: request.requester.avatarURL?.absoluteString,
                createdAt: request.createdAt
            )
        }
        syncService.syncFriendRequests(previews)
    }

    func refreshFriendRequestsFromNetwork() async {
        let requests = (try? await fetchIncomingFriendRequestsUseCase.executeAll()) ?? []
        syncFriendRequests(requests)
    }

    func clearAll() {
        syncService.clearAll()
    }

    private func messagePreview(for conversation: Conversation) -> String {
        guard let message = conversation.lastMessage else {
            return "Không có tin nhắn"
        }
        if !message.body.isEmpty {
            return message.body
        }
        if !message.imageAttachments.isEmpty {
            return "📷 Ảnh"
        }
        return "Tin nhắn mới"
    }

    private func avatarURL(for conversation: Conversation) -> String? {
        if conversation.isGroup {
            return conversation.groupAvatarUrl
        }
        return conversation.peer?.avatarUrl
    }
}
