import SwiftUI
import DesignSystem
import Common
import SplickDomain

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
    let post: Post
    let currentUser: UserSummary?
    let onReact: (String) -> Void
    let onDelete: () -> Void
    let onUserTap: (UserSummary) -> Void
    let onOpenComments: () -> Void
    let onShowCompanions: () -> Void
    /// When false (e.g. post detail), reactions/views still show; only the comment preview link is hidden.
    var showsCommentPreview: Bool = true

    @State private var activeSheet: PostCardSheet?
    @State private var reminderSentMessage: String?
    @State private var cardFrameInGlobal: CGRect = .zero
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

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            authorHeader

            if let caption = post.caption, !caption.isEmpty {
                captionSection(caption)
            }

            companionsSection
            PostMediaView(post: post)
            contextSection

            reactionBarRow
            reactionSummaryRow

            if showsCommentPreview {
                commentPreviewRow
            }
        }
        .splickCard()
        .coordinateSpace(name: "postCard")
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { cardFrameInGlobal = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { frame in
                        cardFrameInGlobal = frame
                    }
            }
        )
        .onPreferenceChange(ReactionTargetAnchorsKey.self) { reactionAnchors = $0 }
        .overlay {
            ForEach(flyingEmojis) { flight in
                FlyingEmojiView(flight: flight) {
                    flyingEmojis.removeAll { $0.id == flight.id }
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .reactions:
                ReactionDetailSheet(summaries: post.userReactionSummaries())
            case .emojiPicker:
                EmojiPickerSheet { emoji in
                    onReact(emoji)
                }
            case .viewers:
                ViewersListSheet(viewers: post.viewers, onUserTap: onUserTap)
            case .share:
                SharePostSheet(post: post)
            }
        }
        .alert(
            "Đã gửi",
            isPresented: Binding(
                get: { reminderSentMessage != nil },
                set: { if !$0 { reminderSentMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { reminderSentMessage = nil }
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
                    size: .small
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
        Text(caption)
            .font(SplickTheme.Typography.callout)
            .foregroundStyle(SplickTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Companions

    @ViewBuilder
    private var companionsSection: some View {
        if let summary = post.companionsSummaryText() {
            Button(action: onShowCompanions) {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)

                    HStack(alignment: .center, spacing: 5) {
                        Text("Đang ở cùng \(summary)")
                            .font(.system(size: 11))
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

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
                    Text("Check-in tại \(place)")
                        .font(.system(size: 11))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
            }
        case .shareBill:
            if let bill = post.billSplit {
                BillSplitSectionView(
                    bill: bill,
                    onUserTap: onUserTap,
                    onSendReminder: { user, _ in
                        reminderSentMessage = "Đã gửi nhắc nhở tới \(user.displayName)"
                    },
                    onSendAllReminders: { users, _ in
                        reminderSentMessage = "Đã gửi nhắc nhở tới \(users.count) người"
                    }
                )
            }
        }
    }

    // MARK: - Reactions

    private var reactionBarRow: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
            InlineReactionBar(
                onReact: onReact,
                onDragRelease: { emoji, sourceGlobal in
                    scheduleFlyingEmoji(emoji: emoji, sourceGlobal: sourceGlobal)
                },
                onCustomEmoji: { activeSheet = .emojiPicker }
            )

            Spacer(minLength: 0)

            viewsEntryButton
        }
        .padding(.top, SplickTheme.Spacing.xxs)
    }

    private var viewsEntryButton: some View {
        Button { activeSheet = .viewers } label: {
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 14))
                Text("\(displayViewCount)")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var commentIconWithCount: some View {
        HStack(spacing: 4) {
            Image(systemName: "bubble.right")
                .font(.system(size: 12))
            if post.topLevelCommentCount > 0 {
                Text("\(post.topLevelCommentCount)")
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .foregroundStyle(SplickTheme.Colors.textSecondary)
    }

    private func scheduleFlyingEmoji(emoji: String, sourceGlobal: CGRect) {
        let origin = cardFrameInGlobal.origin
        let start = CGPoint(
            x: sourceGlobal.midX - origin.x,
            y: sourceGlobal.midY - origin.y
        )
        let end = flyTargetPoint()
        let flight = FlyingEmojiFlight.make(emoji: emoji, start: start, end: end)
        flyingEmojis.append(flight)
        if flyingEmojis.count > 40 {
            flyingEmojis.removeFirst(flyingEmojis.count - 40)
        }
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
                HStack(spacing: 10) {
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

    @ViewBuilder
    private var commentPreviewRow: some View {
        NavigationLink(value: post.id) {
            HStack(spacing: 6) {
                commentIconWithCount

                Group {
                    if post.topLevelCommentCount > 0 {
                        Text("Xem tất cả \(post.topLevelCommentCount) bình luận")
                    } else {
                        Text("Viết bình luận...")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}
