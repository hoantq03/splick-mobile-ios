import SwiftUI
import DesignSystem
import Localization
import SplickDomain
import FeatureFriends
import FeatureStickers

/// Loads post data if needed, then shows `PostDetailView` (avoids blank navigation).
struct PostDetailContainerView: View {
    @EnvironmentObject private var languageService: LanguageService
    let destination: FeedPostDestination
    @ObservedObject var feedViewModel: FeedViewModel
    let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?
    let profileDependencies: FriendUserProfileDependencies?
    let makeGifPickerViewModel: GifPickerViewModelFactory?
    /// Called when the post is unavailable (403/404) and the user dismisses the error.
    var onClose: (() -> Void)? = nil

    @State private var loadAttemptFinished = false
    @State private var loadFailedAsUnavailable = false

    private var post: Post? {
        feedViewModel.posts.first(where: { $0.id == destination.postId })
    }

    var body: some View {
        Group {
            if let post {
                PostDetailView(
                    post: post,
                    initialMediaIndex: destination.mediaIndex,
                    feedViewModel: feedViewModel,
                    fetchFriendsUseCase: fetchFriendsUseCase,
                    profileDependencies: profileDependencies,
                    makeGifPickerViewModel: makeGifPickerViewModel,
                    expandBillSplitInitially: destination.expandBillSplit,
                    focusComposerOnAppear: destination.focusComposerOnAppear
                )
            } else if !loadAttemptFinished {
                SkeletonShimmerHost {
                    FeedPostCardSkeleton(variant: 0)
                        .padding(.horizontal, SplickTheme.Spacing.md)
                        .padding(.top, SplickTheme.Spacing.md)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if loadFailedAsUnavailable {
                unavailableView
            } else {
                ErrorView(message: languageService.text(.feedPostLoadFailed)) {
                    Task { await loadPost() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadPost() }
    }

    private var unavailableView: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            ErrorView(message: languageService.text(.feedPostUnavailableMessage))
            if let onClose {
                SplickButton(languageService.text(.commonClose), style: .secondary) {
                    onClose()
                }
                .padding(.horizontal, SplickTheme.Spacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadPost() async {
        if post != nil {
            loadAttemptFinished = true
            loadFailedAsUnavailable = false
            return
        }
        loadAttemptFinished = false
        loadFailedAsUnavailable = false
        let result = await feedViewModel.ensurePostLoaded(id: destination.postId)
        loadFailedAsUnavailable = (result == .unavailable)
        loadAttemptFinished = true
    }
}
