import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain
import FeatureFriends
import FeatureStickers

struct PostDetailView: View {
    @EnvironmentObject private var languageService: LanguageService
    let post: Post
    let initialMediaIndex: Int
    @ObservedObject var feedViewModel: FeedViewModel
    let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?
    let profileDependencies: FriendUserProfileDependencies?
    let makeGifPickerViewModel: GifPickerViewModelFactory?
    let expandBillSplitInitially: Bool
    let focusComposerOnAppear: Bool

    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.currentUserSummary) private var currentUserSummary
    @StateObject private var commentPager: PostDetailViewModel
    @State private var profileRoute: ProfileRoute?
    @State private var companionsRoute: CompanionsSheetRoute?
    @State private var replyTarget: PostComment?
    @State private var scrollToCommentId: UUID?
    @State private var showEmojiPicker = false
    @State private var mediaViewerRoute: MediaViewerRoute?
    @State private var composerFocused = false
    @State private var composerHitTestingEnabled = false
    @State private var rejectEvidenceTarget: PostComment?
    @State private var rejectReason = ""
    @State private var gifPickerViewModel: GifPickerViewModel?
    @State private var detailScrollLocked = false

    init(
        post: Post,
        initialMediaIndex: Int = 0,
        feedViewModel: FeedViewModel,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol? = nil,
        profileDependencies: FriendUserProfileDependencies? = nil,
        makeGifPickerViewModel: GifPickerViewModelFactory? = nil,
        expandBillSplitInitially: Bool = false,
        focusComposerOnAppear: Bool = false
    ) {
        self.post = post
        self.initialMediaIndex = initialMediaIndex
        self.feedViewModel = feedViewModel
        self.fetchFriendsUseCase = fetchFriendsUseCase
        self.profileDependencies = profileDependencies
        self.makeGifPickerViewModel = makeGifPickerViewModel
        self.expandBillSplitInitially = expandBillSplitInitially
        self.focusComposerOnAppear = focusComposerOnAppear
        _commentPager = StateObject(wrappedValue: PostDetailViewModel(comments: post.comments))
    }

    private var livePost: Post {
        feedViewModel.posts.first(where: { $0.id == post.id }) ?? post
    }

    private var highlightedCommentId: UUID? {
        replyTarget?.id
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
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
                        onUserTap: { openProfile(for: $0) },
                        onOpenComments: {},
                        onShowCompanions: {
                            companionsRoute = CompanionsSheetRoute(
                                id: livePost.id,
                                companions: livePost.companions
                            )
                        },
                        showsCommentPreview: false,
                        onMediaTap: { index in
                            mediaViewerRoute = MediaViewerRoute(index: index)
                        },
                        onSendBillReminder: { postId, targetUserIds, message in
                            try await feedViewModel.sendBillReminder(
                                postId: postId,
                                targetUserIds: targetUserIds,
                                message: message
                            )
                        },
                        onSubmitPaymentEvidence: { postId, splitId, message, attachments in
                            try await feedViewModel.submitPaymentEvidence(
                                postId: postId,
                                splitId: splitId,
                                message: message,
                                submissionAttachments: attachments
                            )
                        },
                        initiallyExpandedBillSplit: expandBillSplitInitially,
                        initialMediaIndex: initialMediaIndex
                    )

                    commentsSection
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
            }
            .scrollDisabled(detailScrollLocked)
            .onReceive(NotificationCenter.default.publisher(for: FeedScrollLock.notification)) { notification in
                detailScrollLocked = notification.userInfo?["locked"] as? Bool ?? false
            }
            .refreshable {
                await feedViewModel.refreshPost(id: post.id, allowingConcurrentFeedRefresh: true)
            }
            .onChange(of: scrollToCommentId) { commentId in
                guard let commentId else { return }
                scrollToComment(commentId, proxy: scrollProxy)
            }
        }
        .navigationTitle(languageService.text(.feedPostCommentsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            commentComposerInset
        }
        .alert(
            languageService.text(.commonError),
            isPresented: Binding(
                get: { feedViewModel.alertMessage != nil },
                set: { if !$0 { feedViewModel.alertMessage = nil } }
            )
        ) {
            Button(languageService.text(.commonOK), role: .cancel) { feedViewModel.alertMessage = nil }
        } message: {
            Text(feedViewModel.alertMessage ?? "")
        }
        .task { await feedViewModel.refreshPost(id: post.id, allowingConcurrentFeedRefresh: true) }
        .onAppear {
            // Defer @Published updates so we don't publish during view updates.
            Task { @MainActor in
                feedViewModel.updateSession(user: currentUserSummary, userId: currentUserSummary?.id)
                tabBarScrollState?.hide(flushToBottom: true)
                commentPager.refresh(with: livePost.comments)
                commentPager.loadInitial()
                enableComposerInteraction()
            }
        }
        .onDisappear {
            Task { @MainActor in
                tabBarScrollState?.show()
            }
        }
        .onChange(of: livePost.comments) { comments in
            commentPager.refresh(with: comments)
        }
        .onChange(of: replyTarget) { target in
            if target != nil {
                composerFocused = true
            }
        }
        .sheet(item: $profileRoute) { route in
            if let profileDependencies {
                FriendUserProfileView(
                    viewModel: profileDependencies.makeViewModel(user: route.user)
                )
            }
        }
        .sheet(item: $companionsRoute) { route in
            CompanionsListSheet(companions: route.companions) { user in
                companionsRoute = nil
                openProfile(for: user)
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerSheet(currentUserId: currentUserSummary?.id) { emoji in
                if let error = feedViewModel.react(to: post.id, emoji: emoji) {
                    feedViewModel.alertMessage = error
                }
            }
        }
        .fullScreenCover(item: $mediaViewerRoute) { route in
            let mediaItems = livePost.displayMediaItems
            if !mediaItems.isEmpty {
                MediaViewerView(
                    items: mediaItems,
                    initialIndex: min(route.index, mediaItems.count - 1),
                    isPresented: Binding(
                        get: { mediaViewerRoute != nil },
                        set: { if !$0 { mediaViewerRoute = nil } }
                    )
                )
            }
        }
        .alert(
            languageService.text(.feedPaymentEvidenceReject),
            isPresented: Binding(
                get: { rejectEvidenceTarget != nil },
                set: { if !$0 { rejectEvidenceTarget = nil } }
            )
        ) {
            TextField(
                languageService.text(.feedPaymentEvidenceRejectReasonPlaceholder),
                text: $rejectReason
            )
            Button(languageService.text(.feedPaymentEvidenceReject), role: .destructive) {
                guard let target = rejectEvidenceTarget,
                      let evidenceId = target.evidenceId else { return }
                let reason = rejectReason.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !reason.isEmpty else { return }
                Task {
                    await feedViewModel.rejectPaymentEvidence(
                        postId: post.id,
                        evidenceId: evidenceId,
                        reason: reason
                    )
                }
                rejectEvidenceTarget = nil
            }
            Button(languageService.text(.commonCancel), role: .cancel) {
                rejectEvidenceTarget = nil
            }
        } message: {
            Text(languageService.text(.feedPaymentEvidenceRejectReasonPlaceholder))
        }
    }

    private var commentComposerInset: some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            if let replyTarget {
                CommentReplyBanner(replyingTo: replyTarget.author) {
                    self.replyTarget = nil
                }
            }

            CommentComposerView(
                placeholder: composerPlaceholder,
                prefillMentionUsername: replyTarget?.author.username,
                isFocused: $composerFocused,
                groupId: livePost.groupId,
                fetchFriendsUseCase: fetchFriendsUseCase,
                gifPickerViewModel: gifPickerViewModel
            ) { text, attachments in
                Task { await submitComment(text: text, attachments: attachments) }
            }
            .id(replyTarget?.id ?? post.id)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.top, SplickTheme.Spacing.sm)
        .padding(.bottom, SplickTheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background { commentComposerDockBackground }
        .allowsHitTesting(composerHitTestingEnabled)
        .onAppear {
            if gifPickerViewModel == nil {
                gifPickerViewModel = makeGifPickerViewModel?(livePost.groupId)
            }
        }
    }

    private var commentComposerDockBackground: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: SplickTheme.CornerRadius.card,
            topTrailingRadius: SplickTheme.CornerRadius.card
        )
        .fill(SplickTheme.Colors.cardBackground)
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: SplickTheme.CornerRadius.card,
                topTrailingRadius: SplickTheme.CornerRadius.card
            )
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: -3)
        .ignoresSafeArea(edges: .bottom)
    }

    private var composerPlaceholder: String {
        if let replyTarget {
            return "Trả lời \(replyTarget.author.displayName)..."
        }
        return languageService.text(.feedPostWriteComment)
    }

    private func submitComment(text: String, attachments: [CommentSubmissionAttachment]) async {
        let parentId = replyTarget?.id

        let result = await feedViewModel.addComment(
            to: post.id,
            text: text,
            submissionAttachments: attachments,
            parentCommentId: parentId
        )
        if let error = result.error {
            feedViewModel.alertMessage = error
        } else {
            if let parentId {
                commentPager.expandReplies(for: parentId)
            }
            replyTarget = nil
            scrollToCommentId = result.createdCommentId
        }
    }

    private func scrollToComment(_ commentId: UUID, proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(commentId, anchor: .center)
            }
            scrollToCommentId = nil
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.feedPostCommentsHeader))
                .font(SplickTheme.Typography.headline)

            if commentPager.displayedTopLevel.isEmpty {
                Text(languageService.text(.feedPostCommentsEmpty))
                    .font(.system(size: 12))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }

            CommentThreadView(
                comments: commentPager.allComments,
                roots: commentPager.displayedTopLevel,
                expandedParents: commentPager.expandedParents,
                highlightedCommentId: highlightedCommentId,
                repliesPreviewCount: commentPager.repliesPreviewCount,
                canReplyToComment: { feedViewModel.canReply(to: $0) },
                canModerateEvidence: { feedViewModel.canModerateEvidence(on: $0, post: livePost) },
                onReply: { comment in
                    guard feedViewModel.canReply(to: comment) else { return }
                    commentPager.expandAncestorChain(of: comment)
                    replyTarget = comment
                    composerFocused = true
                },
                onUserTap: { openProfile(for: $0) },
                onViewMoreReplies: { parentId in
                    commentPager.expandReplies(for: parentId)
                },
                onApproveEvidence: { comment in
                    guard let evidenceId = comment.evidenceId else { return }
                    Task { await feedViewModel.approvePaymentEvidence(postId: post.id, evidenceId: evidenceId) }
                },
                onRejectEvidence: { comment in
                    rejectEvidenceTarget = comment
                    rejectReason = ""
                }
            )

            if commentPager.canLoadMore {
                Button {
                    commentPager.loadNextPage()
                } label: {
                    if commentPager.isLoadingPage {
                        SplickSpinner(size: .small)
                    } else {
                        Text(languageService.text(.feedPostCommentsLoadMore))
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SplickTheme.Spacing.sm)
            }
        }
    }

    private func openProfile(for user: UserSummary) {
        guard user.id != currentUserSummary?.id else { return }
        profileRoute = ProfileRoute(user: user)
    }

    /// Prevents the feed comment-row tap from passing through to the docked composer after push.
    private func enableComposerInteraction() {
        composerHitTestingEnabled = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            composerHitTestingEnabled = true
            if focusComposerOnAppear {
                composerFocused = true
            }
        }
    }
}

private struct ProfileRoute: Identifiable {
    let user: UserSummary
    var id: UUID { user.id }
}
