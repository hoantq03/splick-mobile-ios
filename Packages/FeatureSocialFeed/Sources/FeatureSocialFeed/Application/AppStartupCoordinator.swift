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
        // Emoji metadata lives only in memory; reload it independently so a failed
        // startup batch (badges, conversations, etc.) does not leave reactions broken.
        await customEmojiStore.load(fetcher: customEmojiFetcher)

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

        do {
            let fresh = try await fetchAppStartupUseCase.execute()
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

        // Fallback when startup failed or returned an empty feed page.
        if feedViewModel.posts.isEmpty {
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
