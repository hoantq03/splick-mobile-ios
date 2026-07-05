import Foundation
import Common
import FeatureMessaging
import FeatureNotification
import FeatureSocialFeed
import SplickDomain

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
        streakViewModel: StreakViewModel
    ) async {
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
