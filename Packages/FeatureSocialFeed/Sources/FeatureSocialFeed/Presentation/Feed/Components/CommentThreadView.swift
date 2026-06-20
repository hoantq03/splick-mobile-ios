import SwiftUI
import DesignSystem
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
    let onReply: (PostComment) -> Void
    let onUserTap: (UserSummary) -> Void
    let onViewMoreReplies: (UUID) -> Void

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
        onReply: @escaping (PostComment) -> Void,
        onUserTap: @escaping (UserSummary) -> Void,
        onViewMoreReplies: @escaping (UUID) -> Void,
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
        self.onReply = onReply
        self.onUserTap = onUserTap
        self.onViewMoreReplies = onViewMoreReplies
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
                onReply: onReply,
                onUserTap: onUserTap,
                onViewMoreReplies: onViewMoreReplies
            )
        }
    }
}

// MARK: - Branch

private struct CommentBranchView: View {

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
    let onReply: (PostComment) -> Void
    let onUserTap: (UserSummary) -> Void
    let onViewMoreReplies: (UUID) -> Void

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
                anchorsThreadForChildren: !children.isEmpty,
                onReply: { onReply(comment) },
                onUserTap: onUserTap
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
                        onReply: onReply,
                        onUserTap: onUserTap,
                        onViewMoreReplies: onViewMoreReplies,
                        parentBranchSpaceName: branchSpaceName
                    )

                    if hiddenReplyCount > 0 {
                        Button {
                            onViewMoreReplies(comment.id)
                        } label: {
                            Text("Xem thêm \(hiddenReplyCount) phản hồi")
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
    var anchorsThreadForChildren: Bool = false
    let onReply: () -> Void
    let onUserTap: (UserSummary) -> Void

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
                    size: .small
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
                HStack(spacing: 5) {
                    Button { onUserTap(comment.author) } label: {
                        Text(comment.author.displayName)
                            .font(.system(size: style.nameFontSize, weight: .semibold))
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)

                    if comment.isEdited {
                        Text("· Đã chỉnh sửa")
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
                        Button("Trả lời", action: onReply)
                            .font(.system(size: style.replyActionFontSize, weight: .medium))
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }
                }
            }
        }
        .padding(.vertical, depth == 0 ? 6 : 4)
        .padding(.horizontal, isHighlighted ? 6 : 0)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 8)
                    .fill(SplickTheme.Colors.tertiaryBackground.opacity(0.9))
            }
        }
    }

    @ViewBuilder
    private var commentBody: some View {
        if comment.isDeleted {
            Text("Bình luận đã bị xóa")
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

    var body: some View {
        if !attachments.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(attachments) { attachment in
                    switch attachment.kind {
                    case .image:
                        if let url = attachment.url {
                            RemoteImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(SplickTheme.Colors.tertiaryBackground)
                                        .overlay { SplickSpinner(size: .small) }
                                }
                            }
                            .frame(maxWidth: maxImageWidth, maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    case .gif:
                        if let url = attachment.url {
                            AnimatedRemoteImage(url: url, contentMode: .fill)
                                .frame(maxWidth: maxImageWidth, maxHeight: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    case .video, .file:
                        HStack(spacing: 6) {
                            Image(systemName: attachment.kind == .video ? "video" : "doc")
                            Text(attachment.fileName ?? attachment.kind.rawValue)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
                }
            }
        }
    }
}
