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
        NavigationStack {
            Group {
                if let media = capturedMedia {
                    composeScreen(for: media)
                } else {
                    MediaCaptureView(
                        onMediaCaptured: { capturedMedia = $0 },
                        onCancel: onDismiss
                    )
                    .ignoresSafeArea()
                }
            }
            .toolbar(.hidden, for: .tabBar)
        }
    }

    @ViewBuilder
    private func composeScreen(for media: CapturedMedia) -> some View {
        let (preview, videoURL, mediaType) = mediaPayload(media)
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
                previewImage: preview,
                videoURL: videoURL,
                mediaType: mediaType,
                createPostUseCase: container.createPostUseCase,
                fetchFriendsUseCase: container.fetchFriendsUseCase,
                currentUser: currentUser,
                currentUserId: currentUser?.id
            ),
            onPosted: {
                appState.selectedTab = .feed
                onDismiss()
            },
            onCancel: { capturedMedia = nil }
        )
    }

    private func mediaPayload(_ media: CapturedMedia) -> (UIImage?, URL?, PostMediaType) {
        switch media {
        case .image(let image):
            return (image, nil, .image)
        case .video(let url):
            return (videoThumbnail(url), url, .video)
        }
    }

    private func videoThumbnail(_ url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
