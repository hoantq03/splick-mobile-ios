import SwiftUI
import UIKit
import FeatureMedia
import FeatureSocialFeed
import FeatureStickers
import SplickDomain

struct PostCaptureFlowView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: DependencyContainer

    let onDismiss: () -> Void

    @State private var capturedMedia: CapturedMedia?
    @State private var gifPickerViewModel: GifPickerViewModel?

    var body: some View {
        Group {
            if let media = capturedMedia {
                NavigationStack {
                    composeScreen(for: media)
                        .toolbar(.hidden, for: .tabBar)
                }
            } else {
                MediaCaptureView(
                    onMediaCaptured: { media in
                        switch media {
                        case .video:
                            break
                        case .image, .images:
                            capturedMedia = media
                        }
                    },
                    onCancel: onDismiss,
                    stickerPickerBuilder: makeStickerPicker,
                    filterCatalogRepository: container.filterCatalogRepository
                )
            }
        }
    }

    @ViewBuilder
    private func composeScreen(for media: CapturedMedia) -> some View {
        let images = mediaImages(media)
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
                previewImages: images,
                fetchFriendsUseCase: container.fetchFriendsUseCase,
                fetchMyGroupsUseCase: container.fetchMyGroupsUseCase,
                fetchGroupMembersUseCase: container.fetchGroupMembersUseCase,
                languageService: container.languageService,
                currentUser: currentUser,
                currentUserId: currentUser?.id,
                feedRepository: container.composeFeedRepository
            ),
            profileDependencies: container.friendUserProfileDependencies,
            nearbyDiscoveryUseCase: container.nearbyDiscoveryUseCase,
            onPostSubmit: { prepared in
                container.feedViewModel.enqueuePostUpload(
                    optimisticPost: prepared.optimisticPost,
                    input: prepared.input
                )
                appState.selectedTab = .feed
                onDismiss()
            },
            onCancel: { capturedMedia = nil }
        )
    }

    private func makeStickerPicker(
        onDismiss: @escaping () -> Void,
        onSelectGifURL: @escaping (URL) -> Void,
        onSelectEmoji: @escaping (String) -> Void
    ) -> AnyView {
        if gifPickerViewModel == nil {
            gifPickerViewModel = container.makeGifPickerViewModel(groupId: nil)
        }
        guard let gifPickerViewModel else {
            return AnyView(EmptyView())
        }

        return AnyView(
            AttachmentPickerView(
                viewModel: gifPickerViewModel,
                currentUserId: appState.currentUser?.id,
                onSelectGif: { sticker in
                    onDismiss()
                    onSelectGifURL(sticker.url)
                },
                onSelectEmoji: { emoji in
                    onDismiss()
                    onSelectEmoji(emoji)
                }
            )
            .environmentObject(container.languageService)
            .environmentObject(container.customEmojiStore)
            .environment(\.customEmojiDependencies, container.customEmojiDependencies)
        )
    }

    private func mediaImages(_ media: CapturedMedia) -> [UIImage] {
        switch media {
        case .image(let image, _):
            return [image]
        case .images(let images):
            return images
        case .video:
            return []
        }
    }
}
