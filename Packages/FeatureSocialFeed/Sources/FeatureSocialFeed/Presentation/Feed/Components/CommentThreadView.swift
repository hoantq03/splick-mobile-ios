import SwiftUI
import DesignSystem
import Localization
import SplickDomain

private enum CommentRowStyle {
    case root
    case reply

    var avatarSize: CGFloat {
        switch self {
        case .root: return 28
        case .reply: return 24
        }
    }

    var nameFontSize: CGFloat {
        switch self {
        case .root: return 12
        case .reply: return 11
        }
    }

    var bodyFontSize: CGFloat {
        switch self {
        case .root: return 12
        case .reply: return 11
        }
    }

    var metaFontSize: CGFloat {
        switch self {
        case .root: return 10
        case .reply: return 9
        }
    }

    var replyActionFontSize: CGFloat {
        switch self {
        case .root: return 11
        case .reply: return 10
        }
    }

    static func forDepth(_ depth: Int) -> CommentRowStyle {
        depth == 0 ? .root : .reply
    }
}

// MARK: - Public entry point

/// Recursive comment tree with Facebook-style thread lines and smaller reply rows.
struct CommentThreadView: View {
    let comments: [PostComment]
    let roots: [PostComment]
    let depth: Int
    let threadGroupId: UUID?
    let expandedParents: Set<UUID>
    let highlightedCommentId: UUID?
    let repliesPreviewCount: Int
    let canReplyToComment: (PostComment) -> Bool
    let canModerateEvidence: (PostComment) -> Bool
    let onReply: (PostComment) -> Void
    let onUserTap: (UserSummary) -> Void
    let onViewMoreReplies: (UUID) -> Void
    let onApproveEvidence: (PostComment) -> Void
    let onRejectEvidence: (PostComment) -> Void

    // The coordinate-space name of the *parent* CommentBranchView that owns the
    // connector column for `threadGroupId`. Passed to each child so replies can
    // report their avatar centers in that space (matching what the connector reads).
    // nil for the root level (no connector above).
    let parentBranchSpaceName: String?

    init(
        comments: [PostComment],
        roots: [PostComment],
        depth: Int = 0,
        threadGroupId: UUID? = nil,
        expandedParents: Set<UUID> = [],
        highlightedCommentId: UUID? = nil,
        repliesPreviewCount: Int = 2,
        canReplyToComment: @escaping (PostComment) -> Bool = { _ in true },
        canModerateEvidence: @escaping (PostComment) -> Bool = { _ in false },
        onReply: @escaping (PostComment) -> Void,
        onUserTap: @escaping (UserSummary) -> Void,
        onViewMoreReplies: @escaping (UUID) -> Void,
        onApproveEvidence: @escaping (PostComment) -> Void = { _ in },
        onRejectEvidence: @escaping (PostComment) -> Void = { _ in },
        parentBranchSpaceName: String? = nil
    ) {
        self.comments = comments
        self.roots = roots
        self.depth = depth
        self.threadGroupId = threadGroupId
        self.expandedParents = expandedParents
        self.highlightedCommentId = highlightedCommentId
        self.repliesPreviewCount = repliesPreviewCount
        self.canReplyToComment = canReplyToComment
        self.canModerateEvidence = canModerateEvidence
        self.onReply = onReply
        self.onUserTap = onUserTap
        self.onViewMoreReplies = onViewMoreReplies
        self.onApproveEvidence = onApproveEvidence
        self.onRejectEvidence = onRejectEvidence
        self.parentBranchSpaceName = parentBranchSpaceName
    }

    var body: some View {
        ForEach(roots) { comment in
            CommentBranchView(
                comment: comment,
                comments: comments,
                depth: depth,
                inheritedThreadGroupId: threadGroupId,
                parentBranchSpaceName: parentBranchSpaceName,
                expandedParents: expandedParents,
                highlightedCommentId: highlightedCommentId,
                repliesPreviewCount: repliesPreviewCount,
                canReplyToComment: canReplyToComment,
                canModerateEvidence: canModerateEvidence,
                onReply: onReply,
                onUserTap: onUserTap,
                onViewMoreReplies: onViewMoreReplies,
                onApproveEvidence: onApproveEvidence,
                onRejectEvidence: onRejectEvidence
            )
        }
    }
}

// MARK: - Branch

private struct CommentBranchView: View {
    @EnvironmentObject private var languageService: LanguageService

    let comment: PostComment
    let comments: [PostComment]
    let depth: Int
    let inheritedThreadGroupId: UUID?
    /// Name of the PARENT branch's coordinate space — used by this comment's
    /// avatar to report its position into the parent's connector metrics.
    let parentBranchSpaceName: String?
    let expandedParents: Set<UUID>
    let highlightedCommentId: UUID?
    let repliesPreviewCount: Int
    let canReplyToComment: (PostComment) -> Bool
    let canModerateEvidence: (PostComment) -> Bool
    let onReply: (PostComment) -> Void
    let onUserTap: (UserSummary) -> Void
    let onViewMoreReplies: (UUID) -> Void
    let onApproveEvidence: (PostComment) -> Void
    let onRejectEvidence: (PostComment) -> Void

    /// A stable named coordinate space owned by this branch view.
    /// All anchors for this branch's own thread are measured in this space.
    private var branchSpaceName: String {
        "commentBranch-\(comment.id.uuidString)"
    }

    /// Leading padding for the replies VStack so replies sit to the right of the
    /// connector hook end: (avatarSize + connectorWidth) / 2.
    private var replyLeadingPadding: CGFloat {
        let avatarSize = CommentRowStyle.forDepth(depth).avatarSize
        return (avatarSize + CommentThreadLayout.connectorWidth) / 2
    }

    /// X of the trunk line in the branch VStack coordinate space = parent avatar center.
    private var trunkX: CGFloat {
        CommentRowStyle.forDepth(depth).avatarSize / 2
    }

    /// X where each L-hook ends = one pixel past the connector column's right edge.
    private var hookEndX: CGFloat {
        trunkX + CommentThreadLayout.connectorWidth / 2 - 1
    }

    private var children: [PostComment] {
        comments.children(of: comment.id)
    }

    private var hiddenReplyCount: Int {
        guard !children.isEmpty else { return 0 }
        if expandedParents.contains(comment.id) { return 0 }
        return max(0, children.count - repliesPreviewCount)
    }

    private var visibleChildren: [PostComment] {
        if expandedParents.contains(comment.id) {
            return children
        }
        return Array(children.prefix(repliesPreviewCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommentRowView(
                comment: comment,
                depth: depth,
                avatarThreadGroupId: inheritedThreadGroupId,
                // Avatar reported in the PARENT's space → parent connector reads it.
                // ThreadStart reported in OWN space → own connector reads it.
                avatarAnchorCoordinateSpace: parentBranchSpaceName.map { .named($0) } ?? .named(branchSpaceName),
                threadStartCoordinateSpace: .named(branchSpaceName),
                isHighlighted: highlightedCommentId == comment.id,
                showsReplyAction: canReplyToComment(comment),
                canModerateEvidence: canModerateEvidence(comment),
                anchorsThreadForChildren: !children.isEmpty,
                onReply: { onReply(comment) },
                onUserTap: onUserTap,
                onApproveEvidence: { onApproveEvidence(comment) },
                onRejectEvidence: { onRejectEvidence(comment) }
            )
            .id(comment.id)

            if !children.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    CommentThreadView(
                        comments: comments,
                        roots: visibleChildren,
                        depth: depth + 1,
                        threadGroupId: comment.id,
                        expandedParents: expandedParents,
                        highlightedCommentId: highlightedCommentId,
                        repliesPreviewCount: repliesPreviewCount,
                        canReplyToComment: canReplyToComment,
                        canModerateEvidence: canModerateEvidence,
                        onReply: onReply,
                        onUserTap: onUserTap,
                        onViewMoreReplies: onViewMoreReplies,
                        onApproveEvidence: onApproveEvidence,
                        onRejectEvidence: onRejectEvidence,
                        parentBranchSpaceName: branchSpaceName
                    )

                    if hiddenReplyCount > 0 {
                        Button {
                            onViewMoreReplies(comment.id)
                        } label: {
                            Text(languageService.format(.feedCommentShowMoreReplies, hiddenReplyCount))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                        .padding(.leading, CommentRowStyle.forDepth(depth + 1).avatarSize + 8)
                    }
                }
                .padding(.leading, replyLeadingPadding)
            }
        }
        .coordinateSpace(name: branchSpaceName)
        // overlayPreferenceValue draws only the connector Path when metrics change —
        // it does NOT re-evaluate the main body (CommentRowView + replies).
        // This avoids the @State → full-body-re-render cascade that caused lag.
        .overlayPreferenceValue(CommentThreadMetricsKey.self) { allMetrics in
            if !children.isEmpty, let metrics = allMetrics[comment.id] {
                CommentThreadConnectorOverlay(
                    metrics: metrics,
                    trunkX: trunkX,
                    hookEndX: hookEndX
                )
            }
        }
    }
}

// MARK: - Connector overlay

/// Draws the trunk + L-hooks directly as a Shape overlay on the branch VStack.
/// Positions are already in the VStack's coordinate space (branchSpaceName),
/// so no GeometryReader conversion is needed — just pass them straight to the shape.
private struct CommentThreadConnectorOverlay: View {
    let metrics: CommentThreadMetrics
    let trunkX: CGFloat
    let hookEndX: CGFloat

    var body: some View {
        let avatarYs = metrics.avatarCenters.values.map { $0.y }.sorted()

        if let startY = metrics.threadStartY, !avatarYs.isEmpty {
            CommentThreadLinesShape(
                startY: startY,
                avatarCentersY: avatarYs,
                trunkX: trunkX,
                hookEndX: hookEndX
            )
            .stroke(
                SplickTheme.Colors.divider,
                style: StrokeStyle(
                    lineWidth: CommentThreadLayout.lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Row

struct CommentRowView: View {
    @EnvironmentObject private var languageService: LanguageService

    let comment: PostComment
    let depth: Int
    var avatarThreadGroupId: UUID? = nil
    /// Coordinate space in which the avatar position is reported.
    /// Must be the PARENT branch's named space so the parent connector reads it.
    var avatarAnchorCoordinateSpace: CoordinateSpace = .named("__unused__")
    /// Coordinate space for the thread-start anchor (own branch's named space).
    var threadStartCoordinateSpace: CoordinateSpace = .named("__unused__")
    let isHighlighted: Bool
    var showsReplyAction: Bool = true
    var canModerateEvidence: Bool = false
    var anchorsThreadForChildren: Bool = false
    let onReply: () -> Void
    let onUserTap: (UserSummary) -> Void
    let onApproveEvidence: () -> Void
    let onRejectEvidence: () -> Void

    private var style: CommentRowStyle { CommentRowStyle.forDepth(depth) }

    private var reportsAvatarToThread: Bool {
        guard let avatarThreadGroupId else { return false }
        return comment.parentCommentId == avatarThreadGroupId
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button { onUserTap(comment.author) } label: {
                AvatarView(
                    imageURL: comment.author.avatarURL,
                    name: comment.author.displayName,
                    size: .small,
                    userId: comment.author.id
                )
                .frame(width: style.avatarSize, height: style.avatarSize)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            // Reports this reply's avatar center to the PARENT connector.
            .modifier(CommentAvatarThreadAnchorModifier(
                isEnabled: reportsAvatarToThread,
                space: avatarAnchorCoordinateSpace,
                threadGroupId: avatarThreadGroupId ?? comment.id,
                commentId: comment.id
            ))
            // Reports the thread-start anchor from the avatar's bottom edge so the
            // trunk line originates directly below the avatar, not below "Trả lời".
            .modifier(CommentThreadStartAnchorModifier(
                isEnabled: anchorsThreadForChildren,
                space: threadStartCoordinateSpace,
                threadGroupId: comment.id
            ))

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                    Button { onUserTap(comment.author) } label: {
                        Text(comment.author.displayName)
                            .font(.system(size: style.nameFontSize, weight: .semibold))
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)

                    if comment.isEvidence {
                        evidenceBadge
                    }

                    if let outcome = comment.moderationOutcome {
                        moderationOutcomeBadge(outcome)
                    }

                    if comment.isEdited {
                        Text(languageService.text(.feedCommentEdited))
                            .font(.system(size: style.metaFontSize))
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }

                    Spacer(minLength: 0)

                    Text(comment.createdAt.relativeString)
                        .font(.system(size: style.metaFontSize))
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }

                commentBody

                if !comment.isDeleted {
                    CommentAttachmentsView(
                        attachments: comment.attachments,
                        maxImageWidth: depth == 0 ? 220 : 200
                    )

                    if showsReplyAction {
                        Button(languageService.text(.messagingReplyAction), action: onReply)
                            .font(.system(size: style.replyActionFontSize, weight: .medium))
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }

                    if canModerateEvidence {
                        evidenceModerationActions
                    }
                }
            }
        }
        .padding(.vertical, depth == 0 ? 6 : 4)
        .padding(.horizontal, isHighlighted ? 6 : 0)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                    .fill(SplickTheme.Colors.tertiaryBackground.opacity(0.9))
            }
        }
    }

    private var evidenceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "banknote")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            Text(languageService.text(.feedPaymentEvidenceBadge))
                .font(.system(size: style.metaFontSize, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .lineLimit(1)
            if let status = comment.evidenceStatus {
                Text("·")
                    .font(.system(size: style.metaFontSize, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                Text(evidenceStatusLabel(status))
                    .font(.system(size: style.metaFontSize, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.xs)
        .padding(.vertical, 3)
        .background {
            Capsule(style: .continuous)
                .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(SplickTheme.Colors.primaryGradientStart.opacity(0.2), lineWidth: 1)
        }
    }

    private func moderationOutcomeBadge(_ outcome: EvidenceStatus) -> some View {
        let label = moderationOutcomeLabel(outcome)
        let tint: Color = outcome == .approved
            ? SplickTheme.Colors.success
            : SplickTheme.Colors.error

        return Text(label)
            .font(.system(size: style.metaFontSize, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, SplickTheme.Spacing.xs)
            .padding(.vertical, 3)
            .background {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(0.2), lineWidth: 1)
            }
    }

    private func moderationOutcomeLabel(_ outcome: EvidenceStatus) -> String {
        switch outcome {
        case .approved: return languageService.text(.feedPaymentEvidenceModerationApproved)
        case .rejected: return languageService.text(.feedPaymentEvidenceModerationRejected)
        case .pending: return ""
        }
    }

    private var evidenceModerationActions: some View {
        HStack(spacing: 8) {
            evidenceModerationButton(
                title: languageService.text(.feedPaymentEvidenceApprove),
                tint: SplickTheme.Colors.success,
                action: onApproveEvidence
            )
            evidenceModerationButton(
                title: languageService.text(.feedPaymentEvidenceReject),
                tint: SplickTheme.Colors.error,
                action: onRejectEvidence
            )
        }
        .padding(.top, 2)
    }

    private func evidenceModerationButton(
        title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: style.replyActionFontSize, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.12))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(tint.opacity(0.2), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func evidenceStatusLabel(_ status: EvidenceStatus) -> String {
        switch status {
        case .pending: return languageService.text(.feedPaymentPending)
        case .approved: return languageService.text(.feedPaymentEvidenceStatusApproved)
        case .rejected: return languageService.text(.feedPaymentEvidenceStatusRejected)
        }
    }

    @ViewBuilder
    private var commentBody: some View {
        if comment.isDeleted {
            Text(languageService.text(.feedCommentDeleted))
                .font(.system(size: style.bodyFontSize))
                .italic()
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        } else if let text = comment.displayText, !text.isEmpty {
            MentionText(text, fontSize: style.bodyFontSize)
        }
    }
}

// MARK: - Thread anchor modifiers

private struct CommentAvatarThreadAnchorModifier: ViewModifier {
    let isEnabled: Bool
    let space: CoordinateSpace
    let threadGroupId: UUID
    let commentId: UUID

    func body(content: Content) -> some View {
        if isEnabled {
            content.reportCommentThreadAnchor(
                space: space,
                threadGroupId: threadGroupId,
                commentId: commentId,
                role: .avatarCenter
            )
        } else {
            content
        }
    }
}

private struct CommentThreadStartAnchorModifier: ViewModifier {
    let isEnabled: Bool
    let space: CoordinateSpace
    let threadGroupId: UUID

    func body(content: Content) -> some View {
        if isEnabled {
            content.reportCommentThreadAnchor(
                space: space,
                threadGroupId: threadGroupId,
                commentId: threadGroupId,
                role: .threadStart
            )
        } else {
            content
        }
    }
}

// MARK: - Attachments

private struct CommentAttachmentsView: View {
    let attachments: [CommentAttachment]
    var maxImageWidth: CGFloat = 220

    @State private var mediaViewerRoute: MediaViewerRoute?

    private var imageAttachments: [CommentAttachment] {
        attachments.filter { $0.kind == .image && $0.url != nil }
    }

    private var otherAttachments: [CommentAttachment] {
        attachments.filter { $0.kind != .image }
    }

    private var imagePreviewModels: [InlineAttachmentPreviewImage] {
        imageAttachments.compactMap(\.inlinePreviewImage)
    }

    private var mediaItems: [PostMediaItem] {
        attachments.enumerated().compactMap { index, attachment in
            guard let url = attachment.url else { return nil }
            switch attachment.kind {
            case .image, .gif:
                return PostMediaItem(
                    id: attachment.id,
                    mediaURL: url,
                    thumbnailURL: attachment.thumbnailURL,
                    mediaType: .image,
                    sortOrder: index
                )
            case .video:
                return PostMediaItem(
                    id: attachment.id,
                    mediaURL: url,
                    thumbnailURL: attachment.thumbnailURL,
                    mediaType: .video,
                    sortOrder: index
                )
            case .file:
                return nil
            }
        }
    }

    var body: some View {
        if !attachments.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if !imagePreviewModels.isEmpty {
                    InlineAttachmentImageGrid(
                        images: imagePreviewModels,
                        maxWidth: maxImageWidth,
                        onTapImage: { imageIndex in
                            guard imageAttachments.indices.contains(imageIndex) else { return }
                            openViewer(for: imageAttachments[imageIndex].id)
                        }
                    )
                }

                ForEach(otherAttachments) { attachment in
                    switch attachment.kind {
                    case .gif:
                        if let url = attachment.url {
                            InlineGifAttachmentView(
                                url: url,
                                previewURL: attachment.thumbnailURL,
                                maxWidth: maxImageWidth
                            )
                            .onTapGesture { openViewer(for: attachment.id) }
                        }
                    case .video:
                        Button {
                            openViewer(for: attachment.id)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "video")
                                Text(attachment.fileName ?? attachment.kind.rawValue)
                                    .lineLimit(1)
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    case .file:
                        HStack(spacing: 6) {
                            Image(systemName: "doc")
                            Text(attachment.fileName ?? attachment.kind.rawValue)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                    case .image:
                        EmptyView()
                    }
                }
            }
            .fullScreenCover(item: $mediaViewerRoute) { route in
                let items = mediaItems
                if !items.isEmpty {
                    MediaViewerView(
                        items: items,
                        initialIndex: min(route.index, items.count - 1),
                        isPresented: Binding(
                            get: { mediaViewerRoute != nil },
                            set: { if !$0 { mediaViewerRoute = nil } }
                        )
                    )
                }
            }
        }
    }

    private func openViewer(for attachmentId: UUID) {
        guard let index = mediaItems.firstIndex(where: { $0.id == attachmentId }) else { return }
        mediaViewerRoute = MediaViewerRoute(index: index)
    }
}
