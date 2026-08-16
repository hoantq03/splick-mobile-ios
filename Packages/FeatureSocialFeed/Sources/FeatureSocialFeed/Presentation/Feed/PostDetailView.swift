import SwiftUI
import PhotosUI
import UIKit
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
    @Environment(\.openProfileSettings) private var openProfileSettings
    @Environment(\.customEmojiDependencies) private var customEmojiDependencies
    @StateObject private var commentPager: PostDetailViewModel
    @State private var profileRoute: ProfileRoute?
    @State private var companionsRoute: CompanionsSheetRoute?
    @State private var replyTarget: PostComment?
    @State private var scrollToCommentId: UUID?
    @State private var scrollToCommentExpectsMedia = false
    @State private var showEmojiPicker = false
    @State private var mediaViewerRoute: MediaViewerRoute?
    @State private var composerFocused = false
    @State private var composerHitTestingEnabled = false
    @State private var rejectEvidenceTarget: PostComment?
    @State private var rejectReason = ""
    @State private var gifPickerViewModel: GifPickerViewModel?
    @State private var detailScrollLocked = false
    @State private var cardPresentation: PostCardPresentation?
    @State private var paymentEvidencePhotoPickerItems: [PhotosPickerItem] = []
    @State private var observedPendingCommentIds = Set<UUID>()
    @StateObject private var cardActions = PostCardActions()

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
                        actions: cardActions,
                        showsCommentPreview: false,
                        initiallyExpandedBillSplit: expandBillSplitInitially,
                        initialMediaIndex: initialMediaIndex
                    )
                    .equatable()

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
                scrollToComment(
                    commentId,
                    expectsMedia: scrollToCommentExpectsMedia,
                    proxy: scrollProxy
                )
            }
            .onChange(of: feedViewModel.pendingCommentIds) { pendingIds in
                let newlyPending = pendingIds.subtracting(observedPendingCommentIds)
                observedPendingCommentIds = pendingIds
                guard let pendingId = livePost.comments.last(where: { newlyPending.contains($0.id) })?.id
                else { return }
                let expectsMedia = livePost.comments.first(where: { $0.id == pendingId })?
                    .attachments.isEmpty == false
                commentPager.ensureCommentVisible(pendingId)
                if let parentId = livePost.comments.first(where: { $0.id == pendingId })?.parentCommentId {
                    commentPager.expandReplies(for: parentId)
                }
                scrollToCommentExpectsMedia = expectsMedia
                scrollToCommentId = pendingId
            }
            .onChange(of: replyTarget) { target in
                guard let target else { return }
                composerFocused = true
                scrollReplyParent(target.id, proxy: scrollProxy)
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
            tabBarScrollState?.hide(flushToBottom: true)
            configureCardActions()
            // Defer remaining @Published updates so we don't publish during view updates.
            Task { @MainActor in
                feedViewModel.updateSession(user: currentUserSummary, userId: currentUserSummary?.id)
                commentPager.refresh(with: livePost.comments)
                commentPager.loadInitial()
                enableComposerInteraction()
            }
        }
        .onDisappear {
            tabBarScrollState?.show()
        }
        .onChange(of: livePost.comments) { comments in
            commentPager.refresh(with: comments)
        }
        .postCardPresentationHost(
            presentation: $cardPresentation,
            currentUser: feedViewModel.currentUser,
            languageService: languageService,
            onUserTap: openProfile,
            onReact: { postId, emoji in
                if let error = feedViewModel.react(to: postId, emoji: emoji) {
                    feedViewModel.alertMessage = error
                }
            },
            onSubmitPaymentEvidence: { postId, splitId, message, attachments in
                try await feedViewModel.submitPaymentEvidence(
                    postId: postId,
                    splitId: splitId,
                    message: message,
                    submissionAttachments: attachments
                )
            },
            onFetchReactions: { postId in
                try await feedViewModel.fetchReactions(for: postId)
            },
            customEmojiDependencies: customEmojiDependencies,
            paymentEvidencePhotoPickerItems: $paymentEvidencePhotoPickerItems,
            onPaymentEvidencePhotosPicked: preparePaymentEvidenceAttachments
        )
        .sheet(item: $profileRoute) { route in
            if let profileDependencies {
                FriendUserProfileView(
                    viewModel: profileDependencies.makeViewModel(
                        user: route.user,
                        currentUserId: currentUserSummary?.id
                    )
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
                    withAnimation(Self.replyBannerAnimation) {
                        self.replyTarget = nil
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    )
                )
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
        }
        .animation(Self.replyBannerAnimation, value: replyTarget?.id)
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

    private static let replyBannerAnimation = Animation.spring(
        response: 0.36,
        dampingFraction: 0.88
    )

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
            return languageService.format(.feedCommentReplyPlaceholder, replyTarget.author.displayName)
        }
        return languageService.text(.feedPostWriteComment)
    }

    private func submitComment(text: String, attachments: [CommentSubmissionAttachment]) async {
        let parentId = replyTarget?.id
        let expectsMedia = !attachments.isEmpty

        let result = await feedViewModel.addComment(
            to: post.id,
            text: text,
            submissionAttachments: attachments,
            parentCommentId: parentId
        )
        if let error = result.error {
            feedViewModel.alertMessage = error
            return
        }

        withAnimation(Self.replyBannerAnimation) {
            replyTarget = nil
        }
        composerFocused = false

        // Sync pager immediately — don't wait for `onChange(of: livePost.comments)`.
        commentPager.refresh(with: livePost.comments)
        if let parentId {
            commentPager.expandReplies(for: parentId)
        }
        if let createdId = result.createdCommentId {
            commentPager.ensureCommentVisible(createdId)
            scrollToCommentExpectsMedia = expectsMedia
            scrollToCommentId = createdId
        }
    }

    private func scrollReplyParent(_ commentId: UUID, proxy: ScrollViewProxy) {
        Task { @MainActor in
            commentPager.ensureCommentVisible(commentId)
            // Wait for reply banner slide-in + keyboard before pinning the parent.
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.easeInOut(duration: 0.34)) {
                // Keep parent comment just above the reply dock / composer.
                proxy.scrollTo(commentId, anchor: UnitPoint(x: 0.5, y: 0.82))
            }
            try? await Task.sleep(nanoseconds: 280_000_000)
            withAnimation(.easeInOut(duration: 0.28)) {
                proxy.scrollTo(commentId, anchor: UnitPoint(x: 0.5, y: 0.82))
            }
        }
    }

    private func scrollToComment(
        _ commentId: UUID,
        expectsMedia: Bool,
        proxy: ScrollViewProxy
    ) {
        Task { @MainActor in
            commentPager.ensureCommentVisible(commentId)
            // Image/GIF rows need more time for LazyVStack + remote media layout.
            let initialDelay: UInt64 = expectsMedia ? 320_000_000 : 160_000_000
            let retryDelay: UInt64 = expectsMedia ? 380_000_000 : 220_000_000
            try? await Task.sleep(nanoseconds: initialDelay)
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(commentId, anchor: UnitPoint(x: 0.5, y: 0.28))
            }
            try? await Task.sleep(nanoseconds: retryDelay)
            withAnimation(.easeInOut(duration: 0.28)) {
                proxy.scrollTo(commentId, anchor: UnitPoint(x: 0.5, y: 0.28))
            }
            if expectsMedia {
                try? await Task.sleep(nanoseconds: 420_000_000)
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(commentId, anchor: UnitPoint(x: 0.5, y: 0.28))
                }
            }
            if scrollToCommentId == commentId {
                scrollToCommentId = nil
                scrollToCommentExpectsMedia = false
            }
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
                post: livePost,
                comments: commentPager.allComments,
                roots: commentPager.displayedTopLevel,
                expandedParents: commentPager.expandedParents,
                highlightedCommentId: highlightedCommentId,
                pendingCommentIds: feedViewModel.pendingCommentIds,
                repliesPreviewCount: commentPager.repliesPreviewCount,
                canReplyToComment: { feedViewModel.canReply(to: $0) },
                canModerateEvidence: { feedViewModel.canModerateEvidence(on: $0, post: livePost) },
                onReply: { comment in
                    guard feedViewModel.canReply(to: comment) else { return }
                    commentPager.expandAncestorChain(of: comment)
                    withAnimation(Self.replyBannerAnimation) {
                        replyTarget = comment
                    }
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
        if user.id == currentUserSummary?.id {
            openProfileSettings?()
            return
        }
        profileRoute = ProfileRoute(user: user)
    }

    private func configureCardActions() {
        cardActions.onReact = { postId, emoji in
            if let error = feedViewModel.react(to: postId, emoji: emoji) {
                feedViewModel.alertMessage = error
            }
        }
        cardActions.onDelete = { postId in
            Task { await feedViewModel.deletePost(id: postId) }
        }
        cardActions.onUserTap = { openProfile(for: $0) }
        cardActions.onOpenComments = { _ in }
        cardActions.onShowCompanions = { post in
            companionsRoute = CompanionsSheetRoute(id: post.id, companions: post.companions)
        }
        cardActions.onMediaTap = { _, index in
            mediaViewerRoute = MediaViewerRoute(index: index)
        }
        cardActions.onPresent = { presentation in
            cardPresentation = presentation
        }
        cardActions.onSendBillReminder = { postId, targetUserIds, message, attachments in
            try await feedViewModel.sendBillReminder(
                postId: postId,
                targetUserIds: targetUserIds,
                message: message,
                submissionAttachments: attachments
            )
        }
        cardActions.onSubmitPaymentEvidence = { postId, splitId, message, attachments in
            try await feedViewModel.submitPaymentEvidence(
                postId: postId,
                splitId: splitId,
                message: message,
                submissionAttachments: attachments
            )
        }
        cardActions.makeGifPickerViewModel = makeGifPickerViewModel
    }

    @MainActor
    private func preparePaymentEvidenceAttachments(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        guard case .paymentEvidencePhotoPicker(let evidencePost) = cardPresentation else { return }

        var attachments: [CommentSubmissionAttachment] = []
        for (index, item) in items.prefix(3).enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpegData = image.jpegData(compressionQuality: 0.92) else { continue }
            attachments.append(
                CommentSubmissionAttachment(
                    kind: .image,
                    data: jpegData,
                    mimeType: "image/jpeg",
                    fileName: "payment-proof-\(index + 1).jpg"
                )
            )
        }

        paymentEvidencePhotoPickerItems = []
        guard !attachments.isEmpty,
              let split = evidencePost.billSplitLine(for: feedViewModel.currentUser?.id ?? UUID()) else {
            cardPresentation = nil
            return
        }
        cardPresentation = .paymentEvidence(
            evidencePost,
            splitId: split.id,
            attachments: attachments
        )
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
