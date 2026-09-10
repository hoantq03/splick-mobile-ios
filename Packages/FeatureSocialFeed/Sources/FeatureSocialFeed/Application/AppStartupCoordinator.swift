import Foundation
import Common
import FeatureMessaging
import FeatureNotification

@MainActor
public final class AppStartupCoordinator {
    private let fetchAppStartupUseCase: FetchAppStartupUseCaseProtocol

    public init(fetchAppStartupUseCase: FetchAppStartupUseCaseProtocol) {
        self.fetchAppStartupUseCase = fetchAppStartupUseCase
    }

    public func bootstrap(
        userId: UUID,
        repository: AppStartupRepositoryProtocol,
        badgeCountService: BadgeCountService,
        feedViewModel: FeedViewModel,
        conversationListViewModel: ConversationListViewModel,
        customEmojiStore: CustomEmojiStore,
        customEmojiFetcher: any CustomEmojiFetching,
        streakViewModel: StreakViewModel
    ) async {
        feedViewModel.updateSession(user: nil, userId: userId)

        if let cached = await repository.loadCached(userId: userId) {
            apply(
                cached,
                badgeCountService: badgeCountService,
                feedViewModel: feedViewModel,
                conversationListViewModel: conversationListViewModel,
                customEmojiStore: customEmojiStore,
                streakViewModel: streakViewModel
            )
        }

        // Feed-only disk cache covers cold starts when startup payload is missing/empty.
        await feedViewModel.loadDiskCacheIfNeeded()

        async let emojiLoad: Void = customEmojiStore.load(fetcher: customEmojiFetcher)

        var startupSucceeded = false
        do {
            let fresh = try await fetchAppStartupUseCase.execute()
            startupSucceeded = true
            apply(
                fresh,
                badgeCountService: badgeCountService,
                feedViewModel: feedViewModel,
                conversationListViewModel: conversationListViewModel,
                customEmojiStore: customEmojiStore,
                streakViewModel: streakViewModel
            )
            await repository.saveCached(fresh, userId: userId)
        } catch {
            Log.error(error, category: .network, metadata: ["action": "fetchStartupData"])
        }

        await emojiLoad

        // Only hit GET /v1/feed when startup succeeded with an empty page — not when offline.
        if feedViewModel.posts.isEmpty, startupSucceeded {
            await feedViewModel.loadFeed()
        }
    }

    private func apply(
        _ data: AppStartupData,
        badgeCountService: BadgeCountService,
        feedViewModel: FeedViewModel,
        conversationListViewModel: ConversationListViewModel,
        customEmojiStore: CustomEmojiStore,
        streakViewModel: StreakViewModel
    ) {
        badgeCountService.apply(data.badgeCounts)
        feedViewModel.applyStartupPosts(data.posts)
        conversationListViewModel.applyStartupConversations(data.conversations)
        customEmojiStore.applyStartupEmojis(data.emojis)
        streakViewModel.applyStartupSummary(
            currentStreak: data.currentStreak,
            hasTodayPhoto: data.hasTodayPhoto
        )
    }
}
