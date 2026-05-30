import SwiftUI
import DesignSystem
import Common
import SplickDomain
import FeatureFriends

struct PhotoAlbumRoute: Hashable {}

public struct PhotoAlbumView: View {
    @ObservedObject private var viewModel: PhotoAlbumViewModel
    @ObservedObject private var feedViewModel: FeedViewModel
    @Binding private var navigationPath: NavigationPath
    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?
    private let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?

    private static let gridSpacing = SplickTheme.Spacing.xs
    private static let cellCornerRadius = SplickTheme.CornerRadius.small

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: Self.gridSpacing),
        count: 4
    )

    public init(
        viewModel: PhotoAlbumViewModel,
        feedViewModel: FeedViewModel,
        navigationPath: Binding<NavigationPath>,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol? = nil
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _feedViewModel = ObservedObject(wrappedValue: feedViewModel)
        _navigationPath = navigationPath
        self.fetchFriendsUseCase = fetchFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
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
                    message: viewModel.hasActiveFilters
                        ? "Không có ảnh phù hợp với bộ lọc hiện tại."
                        : "Ảnh từ bạn và bạn bè sẽ hiện ở đây."
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
            LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                PhotoAlbumFilterBarView(
                    viewModel: viewModel,
                    fetchFriendsUseCase: fetchFriendsUseCase,
                    fetchMyGroupsUseCase: fetchMyGroupsUseCase
                )

                ForEach(viewModel.daySections) { section in
                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                        Text(section.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                            .padding(.leading, SplickTheme.Spacing.xxs)

                        LazyVGrid(columns: columns, spacing: Self.gridSpacing) {
                            ForEach(section.photos) { photo in
                                AlbumPhotoCell(photo: photo, cornerRadius: Self.cellCornerRadius) {
                                    openPost(for: photo)
                                }
                                .onAppear {
                                    if photo.id == viewModel.photos.last?.id {
                                        Task { await viewModel.loadMore() }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.top, SplickTheme.Spacing.xs)

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
    let cornerRadius: CGFloat
    let onTap: () -> Void

    private var cellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        Button(action: onTap) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { photoContent }
                .clipShape(cellShape)
                .contentShape(cellShape)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var photoContent: some View {
        GridThumbnailImage(url: photo.thumbnailURL ?? photo.mediaURL) {
            placeholderContent
        }
    }

    private var placeholderContent: some View {
        cellShape
            .fill(SplickTheme.Colors.tertiaryBackground)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
    }
}
