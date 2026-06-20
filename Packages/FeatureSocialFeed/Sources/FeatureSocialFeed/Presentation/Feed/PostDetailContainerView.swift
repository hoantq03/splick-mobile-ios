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

    @State private var loadAttemptFinished = false

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
                    makeGifPickerViewModel: makeGifPickerViewModel
                )
            } else if !loadAttemptFinished {
                LoadingView(message: languageService.text(.feedLoading))
            } else {
                ErrorView(message: languageService.text(.commonError)) {
                    Task { await loadPost() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadPost() }
    }

    private func loadPost() async {
        if post != nil {
            loadAttemptFinished = true
            return
        }
        _ = await feedViewModel.ensurePostLoaded(id: destination.postId)
        loadAttemptFinished = true
    }
}
