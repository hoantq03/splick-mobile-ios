import SwiftUI
import DesignSystem
import Common
import SplickDomain

struct PostDetailView: View {
    let post: Post
    @ObservedObject var feedViewModel: FeedViewModel
    let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?

    @StateObject private var commentPager: PostDetailViewModel
    @State private var profileRoute: ProfileRoute?
    @State private var companionsRoute: CompanionsSheetRoute?
    @State private var replyParentId: UUID?
    @State private var showEmojiPicker = false

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
                        Task {
                            if let error = await feedViewModel.react(to: post.id, emoji: emoji) {
                                feedViewModel.alertMessage = error
                            }
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
                    showsCommentPreview: false
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
                        attachments: attachments,
                        parentCommentId: replyParentId
                    ) {
                        feedViewModel.alertMessage = error
                    } else {
                        replyParentId = nil
                        if let updated = feedViewModel.posts.first(where: { $0.id == post.id }) {
                            commentPager.refresh(with: updated.comments)
                        }
                    }
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.xs)
            .background(SplickTheme.Colors.background)
        }
        .onAppear { commentPager.loadInitial() }
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
                Task {
                    if let error = await feedViewModel.react(to: post.id, emoji: emoji) {
                        feedViewModel.alertMessage = error
                    }
                }
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text("Bình luận")
                .font(SplickTheme.Typography.headline)

            ForEach(commentPager.displayedTopLevel) { comment in
                commentBlock(comment, isReply: false)

                ForEach(commentPager.replies(for: comment.id)) { reply in
                    commentBlock(reply, isReply: true)
                }
            }

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

    private func commentBlock(_ comment: PostComment, isReply: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if isReply {
                Color.clear.frame(width: 20)
            }

            Button { profileRoute = ProfileRoute(user: comment.author) } label: {
                AvatarView(
                    imageURL: comment.author.avatarURL,
                    name: comment.author.displayName,
                    size: .small
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Button { profileRoute = ProfileRoute(user: comment.author) } label: {
                        Text(comment.author.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(comment.createdAt.relativeString)
                        .font(.system(size: 10))
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }

                if let text = comment.text, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                }

                Button("Trả lời") {
                    replyParentId = isReply ? comment.parentCommentId ?? comment.id : comment.id
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ProfileRoute: Identifiable {
    let user: UserSummary
    var id: UUID { user.id }
}
