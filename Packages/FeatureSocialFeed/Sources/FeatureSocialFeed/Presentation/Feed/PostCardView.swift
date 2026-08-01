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
    let post: Post
    let currentUser: UserSummary?
    let actions: PostCardActions
    /// When false (e.g. post detail), reactions/views still show; only the comment preview link is hidden.
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

            if showsCommentPreview {
                commentPreviewRow
            }
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
        .onPreferenceChange(ReactionTargetAnchorsKey.self) { anchors in
            // Defer @State write off PreferenceKey layout pass.
            guard anchors != reactionAnchors else { return }
            DispatchQueue.main.async {
                guard anchors != reactionAnchors else { return }
                reactionAnchors = anchors
            }
        }
        .overlay {
            GeometryReader { geo in
                let cardOrigin = geo.frame(in: .global).origin
                Color.clear
                    .onAppear { cardOriginGlobal = cardOrigin }
                    .onChange(of: flyingEmojis.count) { _ in
                        cardOriginGlobal = cardOrigin
                    }

                ForEach(flyingEmojis) { flight in
                    FlyingEmojiView(
                        flight: flight,
                        cardOriginGlobal: cardOrigin,
                        onComplete: {
                            // Defer @State mutation off animation/layout coalescing.
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
                AvatarView(
                    imageURL: post.author.avatarURL,
                    name: post.author.displayName,
                    size: .small,
                    userId: post.author.id
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

    @ViewBuilder
    private var postOptionsMenu: some View {
        Menu {
            Button {
                actions.onPresent(.share(post))
            } label: {
                Label(languageService.text(.commonShare), systemImage: "square.and.arrow.up")
            }

            if isAuthor {
                if post.canDelete {
                    Button(languageService.text(.feedPostDelete), systemImage: "trash", role: .destructive) {
                        actions.onDelete(post.id)
                    }
                } else {
                    Button {} label: {
                        Label(
                            languageService.format(.feedPostDeleteBlockedViews, displayViewCount),
                            systemImage: "trash"
                        )
                    }
                    .disabled(true)
                }
            }
            Button(languageService.text(.feedPostReport), systemImage: "flag") {}
            Button(languageService.text(.feedPostHide), systemImage: "eye.slash") {}
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(width: 32, height: 32)
        }
    }

    private func captionSection(_ caption: String) -> some View {
        MentionText(caption, fontSize: 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { actions.onOpenDetail?(post, mediaPageIndex) }
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
                        companionsSummaryLabel

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

    @ViewBuilder
    private var companionsSummaryLabel: some View {
        let bodyFont = Font.system(size: 11)
        let color = SplickTheme.Colors.textSecondary
        let prefix = languageService.text(.feedCompanionsWith) + " "

        if let groupName = post.companionGroupName, !groupName.isEmpty {
            (Text(prefix) + Text(groupName).fontWeight(.semibold))
                .font(bodyFont)
                .foregroundStyle(color)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        } else {
            let maxNamed = 1
            let companions = post.companions
            if companions.count <= maxNamed {
                let names = companions.map(\.displayName).joined(separator: ", ")
                (Text(prefix) + Text(names).fontWeight(.semibold))
                    .font(bodyFont)
                    .foregroundStyle(color)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            } else {
                let first = companions.prefix(maxNamed).map(\.displayName).joined(separator: ", ")
                let others = companions.count - maxNamed
                let suffix = languageService.format(.feedCompanionsAndOthers, others)
                (Text(prefix) + Text(first).fontWeight(.semibold) + Text(suffix))
                    .font(bodyFont)
                    .foregroundStyle(color)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
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
                        ? { actions.onPresent(.paymentEvidencePhotoPicker(post)) }
                        : nil
                )
            }
        }
    }

    /// Reserved / live landing for the current user's avatar under the emoji tray.
    private static let selfAvatarLandingAnchorId = "selfAvatarLanding"

    private enum Layout {
        static let reactionBarHeight: CGFloat = 40
        static let viewsButtonReservedWidth: CGFloat = 52
        static let selfAvatarSize: CGFloat = 28
        /// Tray mid → avatar-row center when preference anchors are not ready yet.
        static let trayToAvatarFallbackOffsetY: CGFloat = 44
        static let selfAvatarLeadingPadding: CGFloat = 0
    }

    private var reactionBarRow: some View {
        ZStack(alignment: .trailing) {
            InlineReactionBar(
                onReact: { emoji in actions.onReact(post.id, emoji) },
                onDragRelease: { emoji, sourceGlobal in
                    scheduleFlyingEmoji(emoji: emoji, sourceGlobal: sourceGlobal)
                },
                onCustomEmoji: { actions.onPresent(.emojiPicker(post)) }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, isAuthor ? Layout.viewsButtonReservedWidth : 0)

            if isAuthor {
                viewsEntryButton
            }
        }
        .frame(height: Layout.reactionBarHeight, alignment: .center)
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
                .font(.system(size: 14))
            Text("\(viewCount)")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
        }
        .foregroundStyle(SplickTheme.Colors.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var commentIconWithCount: some View {
        HStack(spacing: 4) {
            Image(systemName: "bubble.right")
                .font(.system(size: 12))
            if post.commentCount > 0 {
                Text("\(post.commentCount)")
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .foregroundStyle(SplickTheme.Colors.textSecondary)
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

        let badges = HStack(spacing: 6) {
            ForEach(preview.top, id: \.userId) { summary in
                UserReactionBadgeView(summary: summary)
                    .id(summary.userId)
            }

            if preview.otherPeopleCount > 0 {
                MoreReactorsChip(count: preview.otherPeopleCount)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: Layout.selfAvatarSize, alignment: .leading)
        // When the current user is not in the summary yet, keep an invisible
        // avatar-sized target under the tray for the fly-to-self landing.
        .background(alignment: .leading) {
            if !hasMyBadge {
                Color.clear
                    .frame(width: Layout.selfAvatarSize, height: Layout.selfAvatarSize)
                    .reactionTargetAnchor(id: Self.selfAvatarLandingAnchorId)
            }
        }

        if !preview.top.isEmpty || preview.otherPeopleCount > 0 {
            Button { actions.onPresent(.reactions(post)) } label: {
                badges
            }
            .buttonStyle(.plain)
        } else {
            badges
                .accessibilityHidden(true)
        }
    }

    private var commentPreviewRow: some View {
        Button {
            actions.onOpenComments(post)
        } label: {
            HStack(spacing: 6) {
                commentIconWithCount

                Group {
                    if post.commentCount > 0 {
                        Text(languageService.format(.feedPostViewAllComments, post.commentCount))
                    } else {
                        Text(languageService.text(.feedPostWriteComment))
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
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
