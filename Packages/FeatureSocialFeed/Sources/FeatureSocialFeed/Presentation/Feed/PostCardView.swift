import SwiftUI
import DesignSystem
import SplickDomain

struct PostCardView: View {
    let post: Post
    let onReact: (String) -> Void

    private let quickReactions = ["❤️", "😂", "😍", "🔥", "👏"]

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            authorHeader
            imageContent
            reactionBar
            if let caption = post.caption, !caption.isEmpty {
                captionSection(caption)
            }
            timestampSection
        }
        .splickCard()
    }

    // MARK: - Subviews

    private var authorHeader: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            AvatarView(
                imageURL: post.author.avatarURL,
                name: post.author.displayName,
                size: .small
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(post.author.displayName)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)

                Text("@\(post.author.username)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }

            Spacer()

            Menu {
                Button("Report", systemImage: "flag") {}
                Button("Hide", systemImage: "eye.slash") {}
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
    }

    private var imageContent: some View {
        AsyncImage(url: post.imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: 350)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))

            case .failure:
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small)
                    .fill(SplickTheme.Colors.secondaryBackground)
                    .frame(height: 250)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                    }

            default:
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small)
                    .fill(SplickTheme.Colors.secondaryBackground)
                    .frame(height: 250)
                    .overlay(ProgressView())
            }
        }
    }

    private var reactionBar: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            ForEach(quickReactions, id: \.self) { emoji in
                Button { onReact(emoji) } label: {
                    Text(emoji)
                        .font(.title3)
                }
            }

            Spacer()

            if post.reactionCount > 0 {
                Text("\(post.reactionCount)")
                    .font(SplickTheme.Typography.captionBold)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
    }

    private func captionSection(_ caption: String) -> some View {
        HStack(spacing: SplickTheme.Spacing.xxs) {
            Text(post.author.username)
                .font(SplickTheme.Typography.captionBold)
            Text(caption)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
        }
    }

    private var timestampSection: some View {
        Text(post.createdAt.relativeString)
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textTertiary)
    }
}
