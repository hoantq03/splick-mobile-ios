import Foundation
import SplickDomain

public final class WidgetCacheService: Sendable {
    public static let shared = WidgetCacheService()

    private let cacheStore: WidgetCacheStore
    private let imageCache: WidgetImageCache

    public init(
        cacheStore: WidgetCacheStore = .shared,
        imageCache: WidgetImageCache = .shared
    ) {
        self.cacheStore = cacheStore
        self.imageCache = imageCache
    }

    public func loadExpenseSummary() -> WidgetExpenseSummarySnapshot? {
        cacheStore.read(WidgetExpenseSummarySnapshot.self, from: WidgetCacheFile.expenseSummary)
    }

    public func loadMessagingInbox() -> WidgetMessagingInboxSnapshot? {
        cacheStore.read(WidgetMessagingInboxSnapshot.self, from: WidgetCacheFile.messagingInbox)
    }

    public func loadLatestFriendPhoto() -> WidgetLatestFriendPhotoSnapshot? {
        cacheStore.read(WidgetLatestFriendPhotoSnapshot.self, from: WidgetCacheFile.latestFriendPhoto)
    }

    public func loadStreak() -> WidgetStreakSnapshot? {
        cacheStore.read(WidgetStreakSnapshot.self, from: WidgetCacheFile.streak)
    }

    public func loadFriendRequests() -> WidgetFriendRequestsSnapshot? {
        cacheStore.read(WidgetFriendRequestsSnapshot.self, from: WidgetCacheFile.friendRequests)
    }

    public func loadGroups() -> WidgetGroupsSnapshot? {
        cacheStore.read(WidgetGroupsSnapshot.self, from: WidgetCacheFile.groups)
    }

    public func loadGroupExpense(groupId: UUID) -> WidgetGroupExpenseSnapshot? {
        cacheStore.read(
            WidgetGroupExpenseSnapshot.self,
            from: WidgetCacheFile.groupExpense(groupId: groupId)
        )
    }

    public func cachedImageURL(for snapshot: WidgetLatestFriendPhotoSnapshot) -> URL? {
        imageCache.imageURL(for: snapshot.cachedImageFilename)
    }
}

public final class WidgetDataSyncService: Sendable {
    public static let shared = WidgetDataSyncService()

    private let cacheStore: WidgetCacheStore
    private let imageCache: WidgetImageCache

    public init(
        cacheStore: WidgetCacheStore = .shared,
        imageCache: WidgetImageCache = .shared
    ) {
        self.cacheStore = cacheStore
        self.imageCache = imageCache
    }

    public func syncExpenseSummary(debts: [DebtSummary]) {
        let totalOwed = debts.filter(\.isOwed).reduce(Decimal.zero) { $0 + $1.amount }
        let totalOwing = debts.filter(\.owes).reduce(Decimal.zero) { $0 + abs($1.amount) }
        let net = totalOwed - totalOwing
        let currency = debts.first?.currency ?? "VND"

        let topDebts = debts
            .sorted { abs($0.amount) > abs($1.amount) }
            .prefix(5)
            .map { debt in
                WidgetDebtItem(
                    userId: debt.user.id,
                    displayName: debt.user.displayName,
                    amount: WidgetCurrencyFormatter.string(from: abs(debt.amount), currency: debt.currency),
                    currency: debt.currency,
                    isOwed: debt.isOwed
                )
            }

        let snapshot = WidgetExpenseSummarySnapshot(
            netAmount: WidgetCurrencyFormatter.signedString(from: net, currency: currency),
            currency: currency,
            totalOwing: WidgetCurrencyFormatter.string(from: totalOwing, currency: currency),
            totalOwed: WidgetCurrencyFormatter.string(from: totalOwed, currency: currency),
            owingPeopleCount: debts.filter(\.owes).count,
            owedPeopleCount: debts.filter(\.isOwed).count,
            topDebts: Array(topDebts)
        )

        try? cacheStore.write(snapshot, to: WidgetCacheFile.expenseSummary)
        WidgetTimelineReloader.reload(WidgetKind.expenseSummary)
    }

    public func syncGroupExpense(
        group: Group,
        expenses: [Expense],
        debts: [DebtSummary],
        currentUserId: UUID?
    ) {
        let totalAmount = expenses.reduce(Decimal.zero) { $0 + $1.totalAmount }
        let settledCount = expenses.filter { $0.status == .settled }.count
        let settledPercentage = expenses.isEmpty
            ? 0
            : Int((Double(settledCount) / Double(expenses.count)) * 100)

        let memberBalances = debts.prefix(8).map { debt in
            WidgetGroupMemberBalance(
                userId: debt.user.id,
                displayName: debt.user.displayName,
                amount: WidgetCurrencyFormatter.string(from: abs(debt.amount), currency: debt.currency),
                isOwed: debt.isOwed
            )
        }

        let snapshot = WidgetGroupExpenseSnapshot(
            groupId: group.id,
            groupName: group.name,
            totalAmount: WidgetCurrencyFormatter.string(from: totalAmount, currency: debts.first?.currency ?? "VND"),
            settledPercentage: settledPercentage,
            currency: debts.first?.currency ?? "VND",
            memberBalances: Array(memberBalances)
        )

        try? cacheStore.write(snapshot, to: WidgetCacheFile.groupExpense(groupId: group.id))
        WidgetTimelineReloader.reload(WidgetKind.groupExpense)
        _ = currentUserId
    }

    public func syncGroups(_ groups: [Group]) {
        let snapshot = WidgetGroupsSnapshot(
            groups: groups.map {
                WidgetGroupOption(id: $0.id, name: $0.name, memberCount: $0.memberCount)
            }
        )
        try? cacheStore.write(snapshot, to: WidgetCacheFile.groups)
        WidgetTimelineReloader.reload(WidgetKind.groupExpense)
    }

    public func syncMessagingInbox(
        conversations: [WidgetConversationPreviewInput],
        totalUnreadCount: Int
    ) {
        let snapshot = WidgetMessagingInboxSnapshot(
            totalUnreadCount: totalUnreadCount,
            conversations: conversations.map(\.preview)
        )
        try? cacheStore.write(snapshot, to: WidgetCacheFile.messagingInbox)
        WidgetTimelineReloader.reload(WidgetKind.unreadMessages)
    }

    public func syncLatestFriendPhoto(
        post: Post?,
        currentUserId: UUID?
    ) async {
        guard let post,
              post.author.id != currentUserId,
              post.mediaType == .image else {
            try? cacheStore.write(
                WidgetLatestFriendPhotoSnapshot(
                    postId: UUID(),
                    authorName: "",
                    authorUsername: "",
                    reactionCount: 0,
                    createdAt: .now,
                    cachedImageFilename: nil,
                    remoteImageURL: nil
                ),
                to: WidgetCacheFile.latestFriendPhoto
            )
            WidgetTimelineReloader.reload(WidgetKind.latestFriendPhoto)
            return
        }

        let imageURL = post.thumbnailURL ?? post.imageURL
        let filename = "post_\(post.id.uuidString.lowercased()).jpg"
        let cachedFilename = await imageCache.cacheImage(from: imageURL, filename: filename)

        let snapshot = WidgetLatestFriendPhotoSnapshot(
            postId: post.id,
            authorName: post.author.displayName,
            authorUsername: post.author.username,
            reactionCount: post.reactions.count,
            createdAt: post.createdAt,
            cachedImageFilename: cachedFilename,
            remoteImageURL: imageURL.absoluteString
        )

        try? cacheStore.write(snapshot, to: WidgetCacheFile.latestFriendPhoto)
        WidgetTimelineReloader.reload(WidgetKind.latestFriendPhoto)
    }

    public func syncStreak(_ summary: StreakSummary) {
        let snapshot = WidgetStreakSnapshot(
            currentStreak: summary.currentStreak,
            hasTodayPhoto: summary.hasTodayPhoto
        )
        try? cacheStore.write(snapshot, to: WidgetCacheFile.streak)
        WidgetTimelineReloader.reload(WidgetKind.friendStreak)
    }

    public func syncFriendRequests(_ requests: [WidgetFriendRequestPreviewInput]) {
        let snapshot = WidgetFriendRequestsSnapshot(
            pendingCount: requests.count,
            requests: requests.map(\.preview)
        )
        try? cacheStore.write(snapshot, to: WidgetCacheFile.friendRequests)
        WidgetTimelineReloader.reload(WidgetKind.friendRequest)
    }

    public func clearAll() {
        guard let directory = WidgetAppGroup.cacheDirectoryURL else { return }
        try? FileManager.default.removeItem(at: directory)
        WidgetTimelineReloader.reloadAll()
    }
}

public struct WidgetConversationPreviewInput: Sendable {
    public let preview: WidgetConversationPreview

    public init(
        id: UUID,
        displayTitle: String,
        previewText: String,
        unreadCount: Int,
        avatarURL: String?,
        updatedAt: Date
    ) {
        preview = WidgetConversationPreview(
            id: id,
            displayTitle: displayTitle,
            previewText: previewText,
            unreadCount: unreadCount,
            avatarURL: avatarURL,
            updatedAt: updatedAt
        )
    }
}

public struct WidgetFriendRequestPreviewInput: Sendable {
    public let preview: WidgetFriendRequestPreview

    public init(
        id: UUID,
        requesterName: String,
        requesterUsername: String,
        avatarURL: String?,
        createdAt: Date
    ) {
        preview = WidgetFriendRequestPreview(
            id: id,
            requesterName: requesterName,
            requesterUsername: requesterUsername,
            avatarURL: avatarURL,
            createdAt: createdAt
        )
    }
}
