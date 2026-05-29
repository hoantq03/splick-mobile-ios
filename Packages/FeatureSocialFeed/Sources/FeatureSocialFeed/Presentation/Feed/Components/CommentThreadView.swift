import SwiftUI
import DesignSystem
import SplickDomain

struct CommentThreadView: View {
    let comments: [PostComment]
    let roots: [PostComment]
    let depth: Int
    let onReply: (PostComment) -> Void
    let onUserTap: (UserSummary) -> Void

    init(
        comments: [PostComment],
        roots: [PostComment],
        depth: Int = 0,
        onReply: @escaping (PostComment) -> Void,
        onUserTap: @escaping (UserSummary) -> Void
    ) {
        self.comments = comments
        self.roots = roots
        self.depth = depth
        self.onReply = onReply
        self.onUserTap = onUserTap
    }

    var body: some View {
        ForEach(roots) { comment in
            CommentRowView(
                comment: comment,
                depth: depth,
                onReply: onReply,
                onUserTap: onUserTap
            )

            CommentThreadView(
                comments: comments,
                roots: comments.children(of: comment.id),
                depth: depth + 1,
                onReply: onReply,
                onUserTap: onUserTap
            )
        }
    }
}

private struct CommentRowView: View {
    let comment: PostComment
    let depth: Int
    let onReply: (PostComment) -> Void
    let onUserTap: (UserSummary) -> Void

  private var indent: CGFloat { CGFloat(depth) * 20 }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if indent > 0 {
                Color.clear.frame(width: indent)
            }

            Button { onUserTap(comment.author) } label: {
                AvatarView(
                    imageURL: comment.author.avatarURL,
                    name: comment.author.displayName,
                    size: .small
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Button { onUserTap(comment.author) } label: {
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

                CommentAttachmentsView(attachments: comment.attachments)

                Button("Trả lời") {
                    onReply(comment)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CommentAttachmentsView: View {
    let attachments: [CommentAttachment]

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
                            .frame(maxWidth: 220, maxHeight: 160)
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
