import SwiftUI
import UIKit
import DesignSystem
import Common
import Localization
import SplickDomain
import FeatureStickers

struct PostCardView: View, Equatable {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var emojiStore: CustomEmojiStore
    @EnvironmentObject private var presenceStore: PresenceStore
    let post: Post
    let currentUser: UserSummary?
    let actions: PostCardActions
    /// When false (e.g. post detail), reactions/views still show; only the comment entry control is hidden.
    var showsCommentPreview: Bool = true
    /// When true, the bill split section below media starts expanded (e.g. opened from Expenses tab).
    var initiallyExpandedBillSplit: Bool = false
    /// Restores carousel position when opening detail after swiping media in the feed.
    var initialMediaIndex: Int = 0
    var uploadState: PostUploadState? = nil

    @State private var mediaPageIndex = 0
    @State private var appliedInitialMediaIndex = false
    @State private var isMediaPinchZooming = false
    @State private var reminderSentMessage: String?
    @State private var reactionAnchors: [String: CGPoint] = [:]
    @State private var cardOriginGlobal: CGPoint = .zero
    @State private var flyingEmojis: [FlyingEmojiFlight] = []
    @State private var cachedReactionPreview: (top: [UserReactionSummary], otherPeopleCount: Int)?
    @State private var cachedReactionVersion: UInt64?

    static func == (lhs: PostCardView, rhs: PostCardView) -> Bool {
        lhs.post == rhs.post
            && lhs.currentUser?.id == rhs.currentUser?.id
            && lhs.showsCommentPreview == rhs.showsCommentPreview
            && lhs.initiallyExpandedBillSplit == rhs.initiallyExpandedBillSplit
            && lhs.initialMediaIndex == rhs.initialMediaIndex
            && lhs.uploadState == rhs.uploadState
            && lhs.actions === rhs.actions
    }

    private var reactionPreview: (top: [UserReactionSummary], otherPeopleCount: Int) {
        if let cachedReactionPreview, cachedReactionVersion == post.version {
            return cachedReactionPreview
        }
        return post.reactionPreview(topLimit: 3)
    }

    private func refreshReactionPreviewCacheIfNeeded() {
        guard cachedReactionVersion != post.version else { return }
        cachedReactionPreview = post.reactionPreview(topLimit: 3)
        cachedReactionVersion = post.version
    }

    private var isAuthor: Bool {
        guard let currentUser else { return false }
        return post.author.id == currentUser.id
    }

    private var displayViewCount: Int {
        max(post.viewCount, post.viewers.count)
    }

    private var isUploadPending: Bool {
        uploadState != nil
    }

    private var currentUserSplitLine: PostBillSplitLine? {
        guard let currentUser, post.feedKind == .shareBill else { return nil }
        return post.billSplitLine(for: currentUser.id)
    }

    private var shouldShowPaymentEvidenceAction: Bool {
        guard !isAuthor, let currentUserSplitLine, post.feedKind == .shareBill else { return false }
        return currentUserSplitLine.paymentStatus == .unpaid
    }

    var body: some View {
        let signpost = FeedSignposts.beginPostCardBody(postId: post.id)
        return cardBody
            .onAppear { FeedSignposts.endPostCardBody(signpost) }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            authorHeader

            if let caption = post.caption, !caption.isEmpty {
                captionSection(caption)
            } else if post.isEdited {
                editedBadge
            }

            companionsSection
            PostMediaView(
                post: post,
                selectedIndex: $mediaPageIndex,
                onTap: resolvedMediaTap,
                isPinchZooming: $isMediaPinchZooming
            )
            contextSection

            reactionBarRow
            reactionSummaryRow
        }
        .splickCard()
        .zIndex(isMediaPinchZooming ? 100 : 0)
        .blur(radius: uploadState == .uploading ? 2.5 : 0)
        .opacity(isUploadPending ? 0.55 : 1)
        .allowsHitTesting(uploadState != .uploading)
        .overlay {
            if let uploadState {
                PostUploadOverlay(state: uploadState)
                    .allowsHitTesting(uploadState == .uploading)
            }
        }
        .onAppear {
            refreshReactionPreviewCacheIfNeeded()
            guard !appliedInitialMediaIndex, initialMediaIndex > 0 else { return }
            mediaPageIndex = min(initialMediaIndex, max(post.displayMediaItems.count - 1, 0))
            appliedInitialMediaIndex = true
        }
        .onChange(of: post.version) { _ in
            refreshReactionPreviewCacheIfNeeded()
        }
        .coordinateSpace(name: "postCard")
        .environment(\.reactionAnchorTrackingEnabled, !flyingEmojis.isEmpty)
        .onPreferenceChange(ReactionTargetAnchorsKey.self) { anchors in
            guard !anchors.isEmpty, anchors != reactionAnchors else { return }
            DispatchQueue.main.async {
                guard anchors != reactionAnchors else { return }
                reactionAnchors = anchors
            }
        }
        .overlay {
            if !flyingEmojis.isEmpty {
                GeometryReader { geo in
                    let cardOrigin = geo.frame(in: .global).origin
                    Color.clear
                        .onAppear { cardOriginGlobal = cardOrigin }
                        .onChange(of: cardOrigin) { cardOriginGlobal = $0 }

                    ForEach(flyingEmojis) { flight in
                        FlyingEmojiView(
                            flight: flight,
                            cardOriginGlobal: cardOrigin,
                            onComplete: {
                                DispatchQueue.main.async {
                                    flyingEmojis.removeAll { $0.id == flight.id }
                                }
                            }
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .alert(
            languageService.text(.friendsRelationSent),
            isPresented: Binding(
                get: { reminderSentMessage != nil },
                set: { if !$0 { reminderSentMessage = nil } }
            )
        ) {
            Button(languageService.text(.commonOK), role: .cancel) { reminderSentMessage = nil }
        } message: {
            Text(reminderSentMessage ?? "")
        }
    }

    // MARK: - Header

    private var authorHeader: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Button { actions.onUserTap(post.author) } label: {
                AvatarWithPresenceView(
                    imageURL: post.author.avatarURL,
                    name: post.author.displayName,
                    size: .small,
                    userId: post.author.id,
                    showOnlineIndicator: PresenceDisplayPolicy.shouldShowOnlineIndicator(
                        isOnline: resolvedAuthorPresence.isOnline
                    ),
                    lastSeenLabel: PresenceDisplayPolicy.compactLastSeenLabel(
                        isOnline: resolvedAuthorPresence.isOnline,
                        lastSeenAt: resolvedAuthorPresence.lastSeenAt,
                        appLocale: languageService.locale
                    )
                )
            }
            .buttonStyle(.plain)

            Button { actions.onUserTap(post.author) } label: {
                Text(post.author.displayName)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(post.createdAt.relativeString)
                .font(.system(size: 10))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
                .lineLimit(1)

            postOptionsMenu
        }
    }

    private var resolvedAuthorPresence: (isOnline: Bool, lastSeenAt: Date?) {
        _ = presenceStore.states
        if let state = presenceStore.state(for: post.author.id) {
            return (state.isOnline, state.lastSeenAt)
        }
        return (false, nil)
    }

    @ViewBuilder
    private var postOptionsMenu: some View {
        Menu {
            Button {
                actions.onPresent(.share(post))
            } label: {
                Label(languageService.text(.commonShare), systemImage: "square.and.arrow.up")
            }

            if isAuthor {
                Button(languageService.text(.feedPostEdit), systemImage: "pencil") {
                    actions.onEdit(post)
                }
                if post.canDelete {
                    Button(languageService.text(.feedPostDelete), systemImage: "trash", role: .destructive) {
                        actions.onDelete(post.id)
                    }
                } else {
                    Button {} label: {
                        Label(
                            languageService.text(.feedPostDeleteBlockedEvidence),
                            systemImage: "trash"
                        )
                    }
                    .disabled(true)
                }
            }
            Button(languageService.text(.feedPostReport), systemImage: "flag") {}
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(width: 32, height: 32)
        }
    }

    private func captionSection(_ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            MentionText(
                caption,
                fontSize: 16,
                displayNamesByUsername: post.mentionDisplayNamesByUsername,
                onMentionTap: openMentionedUser,
                isSelectable: true,
                displayNamesByUserId: post.mentionDisplayNamesByUserId
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            if post.isEdited {
                editedBadge
            }
        }
    }

    private func openMentionedUser(_ username: String) {
        guard let user = post.userForMentionUsername(username) else { return }
        actions.onUserTap(user)
    }

    private var editedBadge: some View {
        Button {
            actions.onPresent(.editHistory(post))
        } label: {
            Text(languageService.text(.feedPostEdited))
                .font(.caption)
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        }
        .buttonStyle(.plain)
    }

    private var resolvedMediaTap: ((Int) -> Void)? {
        if let onMediaTap = actions.onMediaTap {
            return { index in onMediaTap(post, index) }
        }
        if let onOpenDetail = actions.onOpenDetail {
            return { index in onOpenDetail(post, index) }
        }
        return nil
    }

    // MARK: - Companions

    private var hasCompanionsSummary: Bool {
        if let groupName = post.companionGroupName, !groupName.isEmpty { return true }
        return !post.companions.isEmpty
    }

    @ViewBuilder
    private var companionsSection: some View {
        if hasCompanionsSummary {
            Button { actions.onShowCompanions(post) } label: {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)

                    HStack(alignment: .center, spacing: 5) {
                        CompanionsSummaryText(
                            companions: post.companions,
                            groupName: post.companionGroupName,
                            currentUserId: currentUser?.id
                        )

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bill / Check-in

    @ViewBuilder
    private var contextSection: some View {
        switch post.feedKind {
        case .checkIn:
            if let place = post.checkInPlace {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    Text(languageService.format(.feedCheckInAt, place))
                        .font(.system(size: 11))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
            }
        case .shareBill:
            if let bill = post.billSplit {
                BillSplitSectionView(
                    bill: bill,
                    groupId: post.groupId,
                    onUserTap: { actions.onUserTap($0) },
                    initiallyExpanded: initiallyExpandedBillSplit,
                    onSendReminder: isAuthor
                        ? { user, message, attachments in
                            sendReminder(
                                to: [user],
                                message: message,
                                attachments: attachments,
                                singleName: user.displayName
                            )
                        }
                        : nil,
                    onSendAllReminders: isAuthor
                        ? { users, message, attachments in
                            sendReminder(
                                to: users,
                                message: message,
                                attachments: attachments,
                                singleName: nil,
                                count: users.count
                            )
                        }
                        : nil,
                    makeGifPickerViewModel: actions.makeGifPickerViewModel,
                    paymentStatus: currentUserSplitLine?.paymentStatus,
                    evidenceWasRejected: currentUserSplitLine?.paymentStatus == .unpaid
                        && currentUserSplitLine?.lastRejectedAt != nil,
                    onPaymentTap: shouldShowPaymentEvidenceAction
                        ? {
                            guard let splitId = currentUserSplitLine?.id else { return }
                            actions.onPresent(.paymentEvidence(post, splitId: splitId, attachments: []))
                        }
                        : nil
                )
            }
        }
    }

    /// Reserved / live landing for the current user's avatar under the emoji tray.
    private static let selfAvatarLandingAnchorId = "selfAvatarLanding"

    private enum Layout {
        static let reactionBarHeight: CGFloat = 40
        static let selfAvatarSize: CGFloat = 28
        /// Tray mid → avatar-row center when preference anchors are not ready yet.
        static let trayToAvatarFallbackOffsetY: CGFloat = 44
        static let selfAvatarLeadingPadding: CGFloat = 0
        static let commentIconSize: CGFloat = 36
        static let commentCountFontSize: CGFloat = 13
        static let trailingActionSpacing: CGFloat = 10
    }

    private var reactionBarRow: some View {
        HStack(alignment: .center, spacing: Layout.trailingActionSpacing) {
            InlineReactionBar(
                onReact: { emoji in actions.onReact(post.id, emoji) },
                onDragRelease: { emoji, sourceGlobal in
                    scheduleFlyingEmoji(emoji: emoji, sourceGlobal: sourceGlobal)
                },
                onCustomEmoji: { actions.onPresent(.emojiPicker(post)) }
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsCommentPreview {
                commentEntryButton
            }
        }
        .frame(minHeight: Layout.reactionBarHeight, alignment: .center)
        .padding(.top, SplickTheme.Spacing.xxs)
    }

    private var viewsEntryButton: some View {
        Button { actions.onPresent(.viewers(post)) } label: {
            viewsEntryButtonLabel(viewCount: displayViewCount)
        }
        .buttonStyle(.plain)
    }

    private func viewsEntryButtonLabel(viewCount: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "eye.fill")
                .font(.system(size: 15))
            Text("\(viewCount)")
                .font(.system(size: Layout.commentCountFontSize, weight: .medium))
                .monospacedDigit()
        }
        .foregroundStyle(SplickTheme.Colors.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var commentEntryButton: some View {
        let countLabel = post.commentCount > 0 ? CompactCount.format(post.commentCount) : nil
        return Button {
            actions.onOpenComments(post)
        } label: {
            ZStack {
                Image(systemName: "bubble.right")
                    .font(.system(size: Layout.commentIconSize, weight: .regular))
                    .frame(width: Layout.commentIconSize, height: Layout.commentIconSize)
                if let countLabel {
                    Text(countLabel)
                        .font(.system(size: commentCountFontSize(for: countLabel), weight: .semibold))
                        .monospacedDigit()
                        .offset(y: -2)
                }
            }
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .frame(width: Layout.commentIconSize, height: Layout.reactionBarHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            post.commentCount > 0
                ? languageService.format(.feedPostViewAllComments, post.commentCount)
                : languageService.text(.feedPostWriteComment)
        )
    }

    private func commentCountFontSize(for label: String) -> CGFloat {
        switch label.count {
        case 0, 1, 2: return 12
        case 3: return 10
        default: return 8
        }
    }

    private func scheduleFlyingEmoji(emoji: String, sourceGlobal: CGRect) {
        let end = flyTargetPoint(sourceGlobal: sourceGlobal)
        let flight = FlyingEmojiFlight.make(
            emoji: emoji,
            sourceFrameGlobal: sourceGlobal,
            end: end
        )
        let maxConcurrentFlights = 8
        if flyingEmojis.count >= maxConcurrentFlights {
            flyingEmojis.removeFirst(flyingEmojis.count - maxConcurrentFlights + 1)
        }
        flyingEmojis.append(flight)
    }

    private func flyTargetPoint(sourceGlobal: CGRect) -> CGPoint {
        let startLocal = CGPoint(
            x: sourceGlobal.midX - cardOriginGlobal.x,
            y: sourceGlobal.midY - cardOriginGlobal.y
        )

        if let userId = currentUser?.id {
            let userKey = "user:\(userId.uuidString)"
            // Prefer the reactor's own avatar badge under the tray.
            if let anchor = reactionAnchors[userKey] {
                return anchor
            }
        }

        // First reaction (avatar not mounted yet): reserved slot in the summary row.
        if let landing = reactionAnchors[Self.selfAvatarLandingAnchorId] {
            return landing
        }

        // Last resort: avatar column under the tray — never back onto the emoji tray.
        return CGPoint(
            x: Layout.selfAvatarSize / 2 + Layout.selfAvatarLeadingPadding,
            y: startLocal.y + Layout.trayToAvatarFallbackOffsetY
        )
    }

    @ViewBuilder
    private var reactionSummaryRow: some View {
        let preview = reactionPreview
        let myId = currentUser?.id
        let hasMyBadge = myId.map { id in preview.top.contains(where: { $0.userId == id }) } ?? false
        let hasReactions = !preview.top.isEmpty || preview.otherPeopleCount > 0

        HStack(alignment: .center, spacing: Layout.trailingActionSpacing) {
            reactionPeopleBadges(
                preview: preview,
                hasMyBadge: hasMyBadge,
                tappable: hasReactions
            )

            Spacer(minLength: 0)

            if isAuthor {
                viewsEntryButton
            }
        }
        .frame(minHeight: Layout.selfAvatarSize, alignment: .center)
    }

    @ViewBuilder
    private func reactionPeopleBadges(
        preview: (top: [UserReactionSummary], otherPeopleCount: Int),
        hasMyBadge: Bool,
        tappable: Bool
    ) -> some View {
        let badges = HStack(spacing: 8) {
            if preview.top.isEmpty && preview.otherPeopleCount == 0 {
                Text(languageService.text(.feedReactionsNone))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textPrimary.opacity(0.45))
            } else {
                ForEach(preview.top, id: \.userId) { summary in
                    UserReactionBadgeView(summary: summary)
                        .id(summary.userId)
                }

                if preview.otherPeopleCount > 0 {
                    MoreReactorsChip(count: preview.otherPeopleCount)
                }
            }
        }
        .frame(minHeight: Layout.selfAvatarSize, alignment: .leading)
        .background(alignment: .leading) {
            if !hasMyBadge {
                Color.clear
                    .frame(width: Layout.selfAvatarSize, height: Layout.selfAvatarSize)
                    .reactionTargetAnchor(id: Self.selfAvatarLandingAnchorId)
            }
        }

        if tappable {
            Button { actions.onPresent(.reactions(post)) } label: {
                badges
            }
            .buttonStyle(.plain)
        } else {
            badges
        }
    }

    private func sendReminder(
        to users: [UserSummary],
        message: String,
        attachments: [CommentSubmissionAttachment],
        singleName: String?,
        count: Int? = nil
    ) {
        guard let onSendBillReminder = actions.onSendBillReminder else { return }
        Task {
            do {
                let result = try await onSendBillReminder(
                    post.id,
                    users.map(\.id),
                    message,
                    attachments
                )
                if let singleName {
                    reminderSentMessage = languageService.format(.feedBillReminderSentSingle, singleName)
                } else if let count {
                    reminderSentMessage = languageService.format(
                        .feedBillReminderSentMultiple,
                        result.sentCount,
                        count
                    )
                }
            } catch {
                reminderSentMessage = languageService.localizedMessage(for: error)
            }
        }
    }
}
