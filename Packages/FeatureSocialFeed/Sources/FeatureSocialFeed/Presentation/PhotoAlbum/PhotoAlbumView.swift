import SwiftUI
import Combine
import UIKit
import DesignSystem
import Common
import Localization
import SplickDomain
import FeatureFriends

struct PhotoAlbumRoute: Hashable {}

private enum AlbumScrollAnchor {
    static let top = "albumScrollTop"
}

private struct AlbumPostPreview {
    let post: Post
    let mediaIndex: Int
}

public struct PhotoAlbumView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.feedSegmentScrollState) private var feedSegmentScrollState
    @Environment(\.sameTabTapHandlingEnabled) private var sameTabTapHandlingEnabled
    @Environment(\.currentUserSummary) private var currentUserSummary
    @ObservedObject private var viewModel: PhotoAlbumViewModel
    @ObservedObject private var feedViewModel: FeedViewModel
    @Binding private var navigationPath: NavigationPath
    @State private var postPreview: AlbumPostPreview?
    @State private var previewLoadingPostId: UUID?
    @State private var refreshController = SplickRefreshController()
    @State private var scrollTopSignal = 0
    private let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol?
    private let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?
    private let isEmbedded: Bool

    private static let gridSpacing = SplickTheme.Spacing.xs
    private static let cellCornerRadius = SplickTheme.CornerRadius.small
    /// Extra scroll room so the last thumbnail row clears the floating tab bar.
    private static var bottomScrollClearance: CGFloat {
        SplickTabBarMetrics.floatingClearance + SplickTheme.Spacing.lg
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: Self.gridSpacing),
        count: 4
    )

    private var hasScrollablePhotos: Bool {
        !viewModel.photos.isEmpty
    }

    private var sameTabTapPublisher: AnyPublisher<Void, Never> {
        tabBarScrollState?.sameTabTapSubject.eraseToAnyPublisher()
            ?? Empty().eraseToAnyPublisher()
    }

    public init(
        viewModel: PhotoAlbumViewModel,
        feedViewModel: FeedViewModel,
        navigationPath: Binding<NavigationPath>,
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol? = nil,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol? = nil,
        isEmbedded: Bool = false
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _feedViewModel = ObservedObject(wrappedValue: feedViewModel)
        _navigationPath = navigationPath
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
        self.isEmbedded = isEmbedded
    }

    public var body: some View {
        VStack(spacing: 0) {
            PhotoAlbumFilterBarView(
                viewModel: viewModel,
                currentUser: feedViewModel.currentUser ?? currentUserSummary,
                fetchMyFriendsUseCase: fetchMyFriendsUseCase,
                fetchMyGroupsUseCase: fetchMyGroupsUseCase
            )
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.top, SplickTheme.Spacing.xs)
            .padding(.bottom, SplickTheme.Spacing.sm)

            albumContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .feedPagerPageTopInset(isEnabled: isEmbedded)
        .background(SplickTheme.Colors.background)
        .modifier(PhotoAlbumNavigationModifier(isEmbedded: isEmbedded, title: languageService.text(.feedAlbumTitle)))
        .task {
            await viewModel.loadInitialIfNeeded()
        }
        .onReceive(sameTabTapPublisher) { _ in
            handleSameTabTap()
        }
        .overlay {
            if let postPreview {
                PostPeekOverlay(
                    post: postPreview.post,
                    onDismiss: { self.postPreview = nil },
                    onOpen: {
                        let destination = FeedPostDestination(
                            postId: postPreview.post.id,
                            mediaIndex: postPreview.mediaIndex
                        )
                        self.postPreview = nil
                        withFeedPostNavigation {
                            navigationPath.append(destination)
                        }
                    }
                )
                .zIndex(10)
            }
        }
    }

    @ViewBuilder
    private var albumContent: some View {
        switch viewModel.state {
        case .idle, .loading where viewModel.photos.isEmpty:
            FeedAlbumSkeletonLoadingView()

        case .loaded where viewModel.photos.isEmpty:
            ScrollView {
                EmptyStateView(
                    icon: "photo.on.rectangle.angled",
                    title: languageService.text(.feedAlbumEmptyTitle),
                    message: languageService.text(.feedAlbumEmptyMessage)
                )
                .frame(maxWidth: .infinity)
                .padding(.top, SplickTheme.Spacing.xxl)
            }
            .feedPagerScrollInsets()
            .refreshable { await viewModel.refresh() }

        case .loaded, .loading:
            photoScrollView

        case .failed(let message):
            ScrollView {
                ErrorView(message: message) {
                    Task { await viewModel.refresh() }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, SplickTheme.Spacing.xxl)
            }
            .feedPagerScrollInsets()
            .refreshable { await viewModel.refresh() }
        }
    }

    private var photoScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(AlbumScrollAnchor.top)

                LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                    ForEach(viewModel.daySections(languageService: languageService)) { section in
                        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                            Text(section.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                                .padding(.leading, SplickTheme.Spacing.xxs)

                            LazyVGrid(columns: columns, spacing: Self.gridSpacing) {
                                ForEach(section.photos) { photo in
                                    AlbumPhotoCell(
                                        photo: photo,
                                        cornerRadius: Self.cellCornerRadius,
                                        isLoadingPreview: previewLoadingPostId == photo.postId,
                                        onTap: { openPost(for: photo) },
                                        onLongPress: { previewPost(for: photo) }
                                    )
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
                    SkeletonShimmerHost {
                        SkeletonBone(
                            height: 72,
                            shape: .rectangle(cornerRadius: SplickTheme.CornerRadius.small)
                        )
                    }
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.vertical, SplickTheme.Spacing.md)
                }

                Color.clear
                    .frame(height: Self.bottomScrollClearance)
                    .accessibilityHidden(true)
            }
            .feedPagerScrollInsets()
            .feedScrollSoftTopEdge()
            .scrollContentBackground(.hidden)
            .background(SplickTheme.Colors.background)
            .scrollChromeTracking()
            .splickNativeRefreshable(controller: refreshController) {
                await viewModel.refresh()
            }
            .onChange(of: scrollTopSignal) { _ in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    proxy.scrollTo(AlbumScrollAnchor.top, anchor: .top)
                }
                tabBarScrollState?.reset()
                feedSegmentScrollState?.reset()
            }
        }
    }

    private func handleSameTabTap() {
        guard sameTabTapHandlingEnabled else { return }

        if tabBarScrollState?.isAtTop ?? true {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if hasScrollablePhotos {
                refreshController.refresh()
            } else {
                Task { await viewModel.refresh() }
            }
        } else {
            scrollTopSignal += 1
        }
    }

    private func openPost(for photo: AlbumPhoto) {
        Task {
            let loaded = await feedViewModel.ensurePostLoaded(id: photo.postId)
            guard loaded == .loaded else { return }
            let post = feedViewModel.post(byId: photo.postId)
            let mediaIndex = post?.displayMediaItems.firstIndex(where: { $0.id == photo.id }) ?? 0
            withFeedPostNavigation {
                navigationPath.append(
                    FeedPostDestination(postId: photo.postId, mediaIndex: mediaIndex)
                )
            }
        }
    }

    private func previewPost(for photo: AlbumPhoto) {
        guard previewLoadingPostId == nil, postPreview == nil else { return }
        previewLoadingPostId = photo.postId

        Task {
            let loaded = await feedViewModel.ensurePostLoaded(id: photo.postId)
            guard !Task.isCancelled, previewLoadingPostId == photo.postId else { return }
            defer { previewLoadingPostId = nil }
            guard loaded == .loaded,
                  let post = feedViewModel.post(byId: photo.postId) else {
                return
            }
            let mediaIndex = post.displayMediaItems.firstIndex(where: { $0.id == photo.id }) ?? 0
            postPreview = AlbumPostPreview(post: post, mediaIndex: mediaIndex)
        }
    }
}

private struct PhotoAlbumNavigationModifier: ViewModifier {
    let isEmbedded: Bool
    let title: String

    func body(content: Content) -> some View {
        if isEmbedded {
            content
        } else {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct AlbumPhotoCell: View {
    let photo: AlbumPhoto
    let cornerRadius: CGFloat
    let isLoadingPreview: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var didLongPress = false

    private var cellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        Button {
            guard !didLongPress else {
                didLongPress = false
                return
            }
            onTap()
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { photoContent }
                .overlay {
                    if isLoadingPreview {
                        Color.black.opacity(0.28)
                        ProgressView()
                            .tint(.white)
                    }
                }
                .clipShape(cellShape)
                .contentShape(cellShape)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    didLongPress = true
                    onLongPress()
                }
        )
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
