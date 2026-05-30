import SwiftUI
import DesignSystem
import Common
import SplickDomain

struct PhotoAlbumRoute: Hashable {}

public struct PhotoAlbumView: View {
    @ObservedObject private var viewModel: PhotoAlbumViewModel
    @ObservedObject private var feedViewModel: FeedViewModel
    @Binding private var navigationPath: NavigationPath
    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    public init(
        viewModel: PhotoAlbumViewModel,
        feedViewModel: FeedViewModel,
        navigationPath: Binding<NavigationPath>,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _feedViewModel = ObservedObject(wrappedValue: feedViewModel)
        _navigationPath = navigationPath
        self.fetchFriendsUseCase = fetchFriendsUseCase
    }

    public var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading where viewModel.photos.isEmpty:
                LoadingView(message: "Đang tải album...")

            case .loaded where viewModel.photos.isEmpty:
                EmptyStateView(
                    icon: "photo.on.rectangle.angled",
                    title: "Chưa có ảnh",
                    message: "Ảnh từ bạn và bạn bè sẽ hiện ở đây."
                )

            case .loaded, .loading:
                photoGrid

            case .failed(let message):
                ErrorView(message: message) {
                    Task { await viewModel.refresh() }
                }
            }
        }
        .navigationTitle("Album")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadInitialIfNeeded()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(viewModel.photos) { photo in
                    AlbumPhotoCell(photo: photo) {
                        openPost(for: photo)
                    }
                    .onAppear {
                        if photo.id == viewModel.photos.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SplickTheme.Spacing.md)
            }
        }
        .tabBarHideOnScroll()
    }

    private func openPost(for photo: AlbumPhoto) {
        Task {
            let loaded = await feedViewModel.ensurePostLoaded(id: photo.postId)
            guard loaded else { return }
            let post = feedViewModel.posts.first(where: { $0.id == photo.postId })
            let mediaIndex = post?.displayMediaItems.firstIndex(where: { $0.id == photo.id }) ?? 0
            navigationPath.append(
                FeedPostDestination(postId: photo.postId, mediaIndex: mediaIndex)
            )
        }
    }
}

private struct AlbumPhotoCell: View {
    let photo: AlbumPhoto
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RemoteImage(url: photo.thumbnailURL ?? photo.mediaURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder
                default:
                    placeholder
                        .overlay { SplickSpinner(size: .small) }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipped()
        }
        .buttonStyle(.plain)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(SplickTheme.Colors.tertiaryBackground)
            .aspectRatio(1, contentMode: .fill)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
    }
}
