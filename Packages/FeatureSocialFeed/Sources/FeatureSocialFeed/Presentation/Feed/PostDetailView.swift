import SwiftUI
import DesignSystem
import Common
import SplickDomain

struct PostDetailView: View {
    let post: Post
    @ObservedObject var feedViewModel: FeedViewModel
    let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?

    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.currentUserSummary) private var currentUserSummary
    @StateObject private var commentPager: PostDetailViewModel
    @State private var profileRoute: ProfileRoute?
    @State private var companionsRoute: CompanionsSheetRoute?
    @State private var replyParentId: UUID?
    @State private var showEmojiPicker = false
    @State private var showMediaViewer = false
    @State private var viewerInitialIndex = 0

    init(
        post: Post,
        feedViewModel: FeedViewModel,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil
    ) {
        self.post = post
        self.feedViewModel = feedViewModel
        self.fetchFriendsUseCase = fetchFriendsUseCase
        _commentPager = StateObject(wrappedValue: PostDetailViewModel(comments: post.comments))
    }

    private var livePost: Post {
        feedViewModel.posts.first(where: { $0.id == post.id }) ?? post
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                PostCardView(
                    post: livePost,
                    currentUser: feedViewModel.currentUser,
                    onReact: { emoji in
                        if let error = feedViewModel.react(to: post.id, emoji: emoji) {
                            feedViewModel.alertMessage = error
                        }
                    },
                    onDelete: {
                        Task { await feedViewModel.deletePost(id: post.id) }
                    },
                    onUserTap: { profileRoute = ProfileRoute(user: $0) },
                    onOpenComments: {},
                    onShowCompanions: {
                        companionsRoute = CompanionsSheetRoute(
                            id: livePost.id,
                            companions: livePost.companions
                        )
                    },
                    showsCommentPreview: false,
                    onMediaTap: { index in
                        viewerInitialIndex = index
                        showMediaViewer = true
                    }
                )

                commentsSection
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
        }
        .navigationTitle("Bình luận")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            CommentComposerView(
                placeholder: replyParentId == nil ? "Viết bình luận..." : "Trả lời...",
                fetchFriendsUseCase: fetchFriendsUseCase
            ) { text, attachments in
                Task {
                    if let error = await feedViewModel.addComment(
                        to: post.id,
                        text: text,
                        submissionAttachments: attachments,
                        parentCommentId: replyParentId
                    ) {
                        feedViewModel.alertMessage = error
                    } else {
                        replyParentId = nil
                    }
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.xs)
            .padding(.bottom, SplickTabBarMetrics.hiddenClearance)
            .background(SplickTheme.Colors.background)
        }
        .alert(
            "Thông báo",
            isPresented: Binding(
                get: { feedViewModel.alertMessage != nil },
                set: { if !$0 { feedViewModel.alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { feedViewModel.alertMessage = nil }
        } message: {
            Text(feedViewModel.alertMessage ?? "")
        }
        .task { await feedViewModel.refreshPost(id: post.id) }
        .onAppear {
            feedViewModel.updateSession(user: currentUserSummary, userId: currentUserSummary?.id)
            tabBarScrollState?.hide()
            commentPager.loadInitial()
        }
        .onDisappear {
            tabBarScrollState?.show()
        }
        .onChange(of: livePost.comments) { comments in
            commentPager.refresh(with: comments)
        }
        .sheet(item: $profileRoute) { route in
            UserProfileView(user: route.user)
        }
        .sheet(item: $companionsRoute) { route in
            CompanionsListSheet(companions: route.companions) { user in
                companionsRoute = nil
                profileRoute = ProfileRoute(user: user)
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerSheet { emoji in
                if let error = feedViewModel.react(to: post.id, emoji: emoji) {
                    feedViewModel.alertMessage = error
                }
            }
        }
        .fullScreenCover(isPresented: $showMediaViewer) {
            let mediaItems = livePost.displayMediaItems
            if !mediaItems.isEmpty {
                MediaViewerView(
                    items: mediaItems,
                    initialIndex: min(viewerInitialIndex, mediaItems.count - 1),
                    isPresented: $showMediaViewer
                )
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text("Bình luận")
                .font(SplickTheme.Typography.headline)

            if commentPager.displayedTopLevel.isEmpty {
                Text("Chưa có bình luận. Hãy là người đầu tiên!")
                    .font(.system(size: 12))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }

            CommentThreadView(
                comments: commentPager.allComments,
                roots: commentPager.displayedTopLevel,
                onReply: { comment in
                    replyParentId = comment.id
                },
                onUserTap: { profileRoute = ProfileRoute(user: $0) }
            )

            if commentPager.canLoadMore {
                Button {
                    commentPager.loadNextPage()
                } label: {
                    if commentPager.isLoadingPage {
                        ProgressView()
                    } else {
                        Text("Xem thêm bình luận")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SplickTheme.Spacing.sm)
            }
        }
    }
}

private struct ProfileRoute: Identifiable {
    let user: UserSummary
    var id: UUID { user.id }
}
