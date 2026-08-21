import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain

public struct StreakView: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject private var viewModel: StreakViewModel
    /// Unobserved — only used for `ensurePostLoaded` actions, never reads `@Published` state.
    private let feedViewModel: FeedViewModel
    @Binding private var navigationPath: NavigationPath

    public init(
        viewModel: StreakViewModel,
        feedViewModel: FeedViewModel,
        navigationPath: Binding<NavigationPath>
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.feedViewModel = feedViewModel
        self._navigationPath = navigationPath
    }

    public var body: some View {
        switch viewModel.state {
        case .idle, .loading:
            FeedSkeletonLoadingView(cardCount: 2)
                .feedPagerPageTopInset(isEnabled: true)
                .onFirstAppear { Task { await viewModel.loadIfNeeded() } }

        case .failed(let message):
            ErrorView(message: message) {
                Task { await viewModel.refresh() }
            }
            .feedPagerPageTopInset(isEnabled: true)

        case .loaded:
            loadedContent
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        VStack(spacing: 0) {
            streakHeader
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.bottom, SplickTheme.Spacing.md)

            StreakMonthScrollView(
                sections: viewModel.monthSections,
                anchorMonthID: viewModel.anchorMonthID,
                scrollToEndToken: viewModel.scrollToEndToken,
                isLoadingOlder: viewModel.isLoadingOlderMonths,
                hasReachedOldestMonth: viewModel.hasReachedOldestMonth,
                canLoadOlder: !viewModel.hasReachedOldestMonth,
                onLoadOlder: { section in
                    await viewModel.loadOlderMonthIfNeeded(for: section)
                },
                onDayTap: { day in
                    viewModel.selectDay(day)
                },
                onRefresh: {
                    await viewModel.refresh()
                }
            )
        }
        .feedPagerPageTopInset(isEnabled: true)
        .background(SplickTheme.Colors.background)
        .sheet(item: $viewModel.selectedDay) { day in
            StreakDayDetailView(
                day: day,
                photos: viewModel.selectedDayPhotos,
                isLoading: viewModel.isDayPhotosLoading,
                onPhotoTap: { photo in
                    openPost(for: photo)
                }
            )
        }
    }

    private func openPost(for photo: AlbumPhoto) {
        Task {
            let loaded = await feedViewModel.ensurePostLoaded(id: photo.postId)
            guard loaded == .loaded else { return }

            let post = feedViewModel.posts.first(where: { $0.id == photo.postId })
            let mediaIndex = post?.displayMediaItems.firstIndex(where: { $0.id == photo.id }) ?? 0

            viewModel.dismissDayDetail()
            withFeedPostNavigation {
                navigationPath.append(
                    FeedPostDestination(postId: photo.postId, mediaIndex: mediaIndex)
                )
            }
        }
    }

    // MARK: - Header

    private var streakHeader: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: viewModel.currentStreak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        viewModel.currentStreak > 0
                            ? Color.orange
                            : SplickTheme.Colors.textSecondary
                    )

                Group {
                    if #available(iOS 17.0, *) {
                        Text("\(viewModel.currentStreak)")
                            .contentTransition(.numericText())
                    } else {
                        Text("\(viewModel.currentStreak)")
                    }
                }
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(SplickTheme.Colors.textPrimary)
            }

            Text(languageService.text(.feedStreakDays))
                .font(.subheadline)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            streakQuoteLine
                .padding(.top, 2)

            if !viewModel.hasTodayPhoto {
                Text(languageService.text(.feedStreakNoPhotosToday))
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
        .padding(.top, SplickTheme.Spacing.md)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.currentStreak)
    }

    private var streakQuoteLine: some View {
        Text("“\(streakQuoteText)”")
            .font(.footnote)
            .italic()
            .foregroundStyle(SplickTheme.Colors.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SplickTheme.Spacing.lg)
            .animation(.easeInOut(duration: 0.25), value: viewModel.currentStreak)
    }

    private var streakQuoteText: String {
        let key: L10nKey = switch viewModel.currentStreak {
        case 0:
            .feedStreakQuoteZero
        case 1...6:
            .feedStreakQuoteGrowing
        case 7...29:
            .feedStreakQuoteSolid
        default:
            .feedStreakQuoteLegend
        }
        return languageService.text(key)
    }
}
