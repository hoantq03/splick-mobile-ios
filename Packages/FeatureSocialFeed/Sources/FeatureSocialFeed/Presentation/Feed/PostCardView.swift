import SwiftUI
import PhotosUI
import UIKit
import DesignSystem
import Common
import Localization
import SplickDomain
import FeatureStickers

private enum PostCardSheet: Identifiable {
    case reactions
    case emojiPicker
    case viewers
    case share

    var id: String {
        switch self {
        case .reactions: "reactions"
        case .emojiPicker: "emojiPicker"
        case .viewers: "viewers"
        case .share: "share"
        }
    }
}

struct PostCardView: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var emojiStore: CustomEmojiStore
    @Environment(\.customEmojiDependencies) private var customEmojiDependencies
    let post: Post
    let currentUser: UserSummary?
    let onReact: (String) -> Void
    let onDelete: () -> Void
    let onUserTap: (UserSummary) -> Void
    let onOpenComments: () -> Void
    let onShowCompanions: () -> Void
    /// When false (e.g. post detail), reactions/views still show; only the comment preview link is hidden.
    var showsCommentPreview: Bool = true
    /// Tap on caption/media (feed) navigates to post detail with the current media page index.
    var onOpenDetail: ((Int) -> Void)? = nil
    /// Tap on a media item in detail opens fullscreen viewer at that index.
    var onMediaTap: ((Int) -> Void)? = nil
    var onSendBillReminder: ((UUID, [UUID]?, String) async throws -> SendBillReminderResult)? = nil
    var onSubmitPaymentEvidence: ((UUID, UUID, String?, [CommentSubmissionAttachment]) async throws -> Void)? = nil
    /// When true, the bill split section below media starts expanded (e.g. opened from Expenses tab).
    var initiallyExpandedBillSplit: Bool = false
    /// Restores carousel position when opening detail after swiping media in the feed.
    var initialMediaIndex: Int = 0
    var uploadState: PostUploadState? = nil

    @State private var mediaPageIndex = 0
    @State private var appliedInitialMediaIndex = false
    @State private var activeSheet: PostCardSheet?
    @State private var showCustomEmojiUpload = false
    @State private var reminderSentMessage: String?
    @State private var showPaymentEvidencePhotoPicker = false
    @State private var showPaymentEvidenceSheet = false
    @State private var paymentEvidencePhotoPickerItems: [PhotosPickerItem] = []
    @State private var paymentEvidenceAttachments: [CommentSubmissionAttachment] = []
    @State private var reactionAnchors: [String: CGPoint] = [:]
    @State private var flyingEmojis: [FlyingEmojiFlight] = []

    private var reactionPreview: (top: [UserReactionSummary], otherPeopleCount: Int) {
        post.reactionPreview(topLimit: 3)
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
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            authorHeader

            if let caption = post.caption, !caption.isEmpty {
                captionSection(caption)
            }

            companionsSection
            PostMediaView(post: post, selectedIndex: $mediaPageIndex, onTap: resolvedMediaTap)
            contextSection

            reactionBarRow
            reactionSummaryRow

            if showsCommentPreview {
                commentPreviewRow
            }
        }
        .splickCard()
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
            guard !appliedInitialMediaIndex, initialMediaIndex > 0 else { return }
            mediaPageIndex = min(initialMediaIndex, max(post.displayMediaItems.count - 1, 0))
            appliedInitialMediaIndex = true
        }
        .coordinateSpace(name: "postCard")
        .onPreferenceChange(ReactionTargetAnchorsKey.self) { reactionAnchors = $0 }
        .overlay {
            GeometryReader { geo in
                let cardOrigin = geo.frame(in: .global).origin
                ForEach(flyingEmojis) { flight in
                    FlyingEmojiView(
                        flight: flight,
                        cardOriginGlobal: cardOrigin,
                        onComplete: {
                            flyingEmojis.removeAll { $0.id == flight.id }
                        }
                    )
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .reactions:
                ReactionDetailSheet(
                    summaries: post.userReactionSummaries(),
                    onUserTap: openProfileFromSheet
                )
            case .emojiPicker:
                EmojiPickerSheet(
                    currentUserId: currentUser?.id,
                    onPick: { emoji in onReact(emoji) },
                    onOpenUpload: { openCustomEmojiUpload() }
                )
            case .viewers:
                ViewersListSheet(viewers: post.viewers, onUserTap: openProfileFromSheet)
            case .share:
                SharePostSheet(post: post)
            }
        }
        .sheet(isPresented: $showCustomEmojiUpload) {
            customEmojiUploadSheet
        }
        .photosPicker(
            isPresented: $showPaymentEvidencePhotoPicker,
            selection: $paymentEvidencePhotoPickerItems,
            maxSelectionCount: 3,
            matching: .images
        )
        .onChange(of: paymentEvidencePhotoPickerItems) { items in
            Task { await preparePaymentEvidenceAttachments(from: items) }
        }
        .sheet(
            isPresented: $showPaymentEvidenceSheet,
            onDismiss: { paymentEvidenceAttachments = [] }
        ) {
            if let split = currentUserSplitLine {
                PaymentEvidenceSheet(
                    postAuthorName: post.author.displayName,
                    initialAttachments: paymentEvidenceAttachments
                ) { message, attachments in
                    try await onSubmitPaymentEvidence?(post.id, split.id, message, attachments)
                }
            }
        }
        .alert(
            "Đã gửi",
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
            Button { onUserTap(post.author) } label: {
                AvatarView(
                    imageURL: post.author.avatarURL,
                    name: post.author.displayName,
                    size: .small,
                    userId: post.author.id
                )
            }
            .buttonStyle(.plain)

            Button { onUserTap(post.author) } label: {
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
                activeSheet = .share
            } label: {
                Label("Chia sẻ", systemImage: "square.and.arrow.up")
            }

            if isAuthor {
                if post.canDelete {
                    Button("Xóa bài", systemImage: "trash", role: .destructive) {
                        onDelete()
                    }
                } else {
                    Button {} label: {
                        Label(
                            "Không thể xóa (đã có \(displayViewCount) lượt xem)",
                            systemImage: "trash"
                        )
                    }
                    .disabled(true)
                }
            }
            Button("Báo cáo", systemImage: "flag") {}
            Button("Ẩn", systemImage: "eye.slash") {}
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
            .onTapGesture { onOpenDetail?(mediaPageIndex) }
    }

    private var resolvedMediaTap: ((Int) -> Void)? {
        if let onMediaTap { return onMediaTap }
        if let onOpenDetail { return onOpenDetail }
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
            Button(action: onShowCompanions) {
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
                    onUserTap: onUserTap,
                    initiallyExpanded: initiallyExpandedBillSplit,
                    onSendReminder: isAuthor
                        ? { user, message in
                            sendReminder(to: [user], message: message, singleName: user.displayName)
                        }
                        : nil,
                    onSendAllReminders: isAuthor
                        ? { users, message in
                            sendReminder(
                                to: users,
                                message: message,
                                singleName: nil,
                                count: users.count
                            )
                        }
                        : nil,
                    paymentStatus: currentUserSplitLine?.paymentStatus,
                    evidenceWasRejected: currentUserSplitLine?.paymentStatus == .unpaid
                        && currentUserSplitLine?.lastRejectedAt != nil,
                    onPaymentTap: shouldShowPaymentEvidenceAction
                        ? {
                            showPaymentEvidencePhotoPicker = true
                        }
                        : nil
                )
            }
        }
    }

    // MARK: - Reactions

    @ViewBuilder
    private var customEmojiUploadSheet: some View {
        if let deps = customEmojiDependencies {
            CustomEmojiUploadSheet(
                currentUserId: currentUser?.id,
                customEmojiFetcher: deps.fetcher,
                uploadMediaUseCase: deps.uploadMediaUseCase,
                addEmojiUseCase: deps.addEmojiUseCase,
                deleteEmojiUseCase: deps.deleteEmojiUseCase
            )
        }
    }

    private func openCustomEmojiUpload() {
        activeSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showCustomEmojiUpload = true
        }
    }

    private func openProfileFromSheet(for user: UserSummary) {
        activeSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onUserTap(user)
        }
    }

    private enum Layout {
        static let reactionBarHeight: CGFloat = 40
        /// Keeps emoji row clear of the views button on the author's post.
        static let viewsButtonReservedWidth: CGFloat = 52
    }

    private var reactionBarRow: some View {
        ZStack(alignment: .trailing) {
            InlineReactionBar(
                onReact: onReact,
                onDragRelease: { emoji, sourceGlobal in
                    scheduleFlyingEmoji(emoji: emoji, sourceGlobal: sourceGlobal)
                },
                onCustomEmoji: { activeSheet = .emojiPicker }
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
        Button { activeSheet = .viewers } label: {
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
        let end = flyTargetPoint()
        let flight = FlyingEmojiFlight.make(
            emoji: emoji,
            sourceFrameGlobal: sourceGlobal,
            end: end
        )
        let maxConcurrentFlights = 16
        if flyingEmojis.count >= maxConcurrentFlights {
            flyingEmojis.removeFirst(flyingEmojis.count - maxConcurrentFlights + 1)
        }
        flyingEmojis.append(flight)
    }

    /// Avatar in top 3, otherwise the "+N người…" chip, otherwise below the bar.
    private func flyTargetPoint() -> CGPoint {
        guard let userId = currentUser?.id else {
            return CGPoint(x: 40, y: 68)
        }

        let preview = post.reactionPreview(topLimit: 3)
        let userKey = "user:\(userId.uuidString)"

        if preview.top.contains(where: { $0.userId == userId }),
           let anchor = reactionAnchors[userKey] {
            return anchor
        }

        if preview.otherPeopleCount > 0, let anchor = reactionAnchors["more"] {
            return anchor
        }

        if let anchor = reactionAnchors[userKey] {
            return anchor
        }

        return CGPoint(x: 40, y: 68)
    }

    @ViewBuilder
    private var reactionSummaryRow: some View {
        let preview = reactionPreview
        if !preview.top.isEmpty {
            Button { activeSheet = .reactions } label: {
                HStack(spacing: 6) {
                    ForEach(preview.top, id: \.userId) { summary in
                        UserReactionBadgeView(summary: summary)
                            .id(summary.userId)
                    }
                    if preview.otherPeopleCount > 0 {
                        MoreReactorsChip(count: preview.otherPeopleCount)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var commentPreviewRow: some View {
        Button {
            if let onOpenDetail {
                onOpenDetail(mediaPageIndex)
            } else {
                onOpenComments()
            }
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
        singleName: String?,
        count: Int? = nil
    ) {
        guard let onSendBillReminder else { return }
        Task {
            do {
                let result = try await onSendBillReminder(
                    post.id,
                    users.map(\.id),
                    message
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

    @MainActor
    private func preparePaymentEvidenceAttachments(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

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

        guard !attachments.isEmpty else { return }
        paymentEvidenceAttachments = attachments
        showPaymentEvidenceSheet = true
    }
}
