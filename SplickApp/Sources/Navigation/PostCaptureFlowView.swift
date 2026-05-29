import SwiftUI
import AVFoundation
import UIKit
import FeatureMedia
import FeatureSocialFeed
import SplickDomain

struct PostCaptureFlowView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer

    let onDismiss: () -> Void

    @State private var capturedMedia: CapturedMedia?

    var body: some View {
        Group {
            if let media = capturedMedia {
                NavigationStack {
                    composeScreen(for: media)
                        .toolbar(.hidden, for: .tabBar)
                }
            } else {
                MediaCaptureView(
                    onMediaCaptured: { capturedMedia = $0 },
                    onCancel: onDismiss
                )
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func composeScreen(for media: CapturedMedia) -> some View {
        let payload = mediaPayload(media)
        let currentUser = appState.currentUser.map {
            UserSummary(
                id: $0.id,
                username: $0.username,
                displayName: $0.displayName,
                avatarURL: $0.avatarURL
            )
        }
        CreatePostComposeView(
            viewModel: CreatePostComposeViewModel(
                previewImages: payload.images,
                videoURL: payload.videoURL,
                mediaType: payload.mediaType,
                createPostUseCase: container.createPostUseCase,
                fetchFriendsUseCase: container.fetchFriendsUseCase,
                currentUser: currentUser,
                currentUserId: currentUser?.id
            ),
            onPosted: { post in
                Task {
                    await container.feedViewModel.syncFeedAfterCreatingPost(post)
                    appState.selectedTab = .feed
                    onDismiss()
                }
            },
            onCancel: { capturedMedia = nil }
        )
    }

    private func mediaPayload(_ media: CapturedMedia) -> (images: [UIImage], videoURL: URL?, mediaType: PostMediaType) {
        switch media {
        case .image(let image):
            return ([image], nil, .image)
        case .images(let images):
            return (images, nil, .image)
        case .video(let url):
            return ([], url, .video)
        }
    }
}
