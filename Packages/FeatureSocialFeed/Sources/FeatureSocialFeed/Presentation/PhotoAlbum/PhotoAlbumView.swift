import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain
import FeatureFriends

struct PhotoAlbumRoute: Hashable {}

public struct PhotoAlbumView: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject private var viewModel: PhotoAlbumViewModel
    @ObservedObject private var feedViewModel: FeedViewModel
    @Binding private var navigationPath: NavigationPath
    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol?
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
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol? = nil,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol? = nil
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _feedViewModel = ObservedObject(wrappedValue: feedViewModel)
        _navigationPath = navigationPath
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
    }

    public var body: some View {
        VStack(spacing: 0) {
            PhotoAlbumFilterBarView(
                viewModel: viewModel,
                fetchMyFriendsUseCase: fetchMyFriendsUseCase,
                fetchMyGroupsUseCase: fetchMyGroupsUseCase
            )
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.top, SplickTheme.Spacing.xs)
            .padding(.bottom, SplickTheme.Spacing.sm)

            albumContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(languageService.text(.feedAlbumTitle))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadInitialIfNeeded()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private var albumContent: some View {
        switch viewModel.state {
        case .idle, .loading where viewModel.photos.isEmpty:
            LoadingView(message: languageService.text(.feedAlbumLoading))

        case .loaded where viewModel.photos.isEmpty:
            EmptyStateView(
                icon: "photo.on.rectangle.angled",
                title: languageService.text(.feedAlbumEmptyTitle),
                message: languageService.text(.feedAlbumEmptyMessage)
            )

        case .loaded, .loading:
            photoScrollView

        case .failed(let message):
            ErrorView(message: message) {
                Task { await viewModel.refresh() }
            }
        }
    }

    private var photoScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
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
