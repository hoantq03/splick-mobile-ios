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
    @StateObject private var gifPickerStore = EditorGifPickerStore()

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
                previewVideoURL: mediaVideoURL(media),
                previewVideoURLs: mediaVideoURLs(media),
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
            stickerPickerBuilder: makeStickerPicker,
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
        let viewModel: GifPickerViewModel
        if let existing = gifPickerStore.viewModel {
            viewModel = existing
        } else {
            let created = container.makeGifPickerViewModel(groupId: nil)
            gifPickerStore.viewModel = created
            viewModel = created
        }

        return AnyView(
            AttachmentPickerView(
                viewModel: viewModel,
                currentUserId: appState.currentUser?.id,
                onSelectGif: { sticker in
                    let url = sticker.url
                    Task { @MainActor in
                        onDismiss()
                        onSelectGifURL(url)
                    }
                },
                onSelectEmoji: { emoji in
                    Task { @MainActor in
                        onDismiss()
                        onSelectEmoji(emoji)
                    }
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
        case .mixed(let images, _):
            return images
        }
    }

    private func mediaVideoURL(_ media: CapturedMedia) -> URL? {
        if case .video(let url) = media { return url }
        return nil
    }

    private func mediaVideoURLs(_ media: CapturedMedia) -> [URL] {
        if case .mixed(_, let videos) = media { return videos }
        return []
    }
}

private final class EditorGifPickerStore: ObservableObject {
    var viewModel: GifPickerViewModel?
}
