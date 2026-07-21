import SwiftUI
import Common
import Localization
import SplickDomain

public struct PostPeekOverlay: View {
    @EnvironmentObject private var languageService: LanguageService

    private let post: Post
    private let onDismiss: () -> Void
    private let onOpen: () -> Void

    @State private var isRevealed = false
    @State private var isDismissing = false

    private static let mediaCornerRadius = SplickTheme.CornerRadius.inset
    private static let sectionCornerRadius = SplickTheme.CornerRadius.inset

    public init(
        post: Post,
        onDismiss: @escaping () -> Void,
        onOpen: @escaping () -> Void
    ) {
        self.post = post
        self.onDismiss = onDismiss
        self.onOpen = onOpen
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .opacity(isRevealed ? 0.52 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissAnimated(completion: onDismiss)
                    }

                previewCard
                    .frame(width: min(geometry.size.width - SplickTheme.Spacing.xl * 2, 420))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxHeight: min(geometry.size.height * 0.78, 640), alignment: .center)
                    .scaleEffect(isRevealed ? 1 : 0.94)
                    .opacity(isRevealed ? 1 : 0)
                    .onTapGesture {
                        dismissAnimated(completion: onOpen)
                    }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                isRevealed = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(languageService.text(.postPreviewAccessibility))
    }

    /// Miniaturized feed card: author → caption → tagged → rounded media.
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            authorHeader

            if let caption = normalizedCaption {
                captionSection(caption)
            }

            if hasTaggedContent {
                taggedSection
            }

            mediaPreview
        }
        .splickCard()
        .contentShape(
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
        )
    }

    private var authorHeader: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            AvatarView(
                imageURL: post.author.avatarURL,
                name: post.author.displayName,
                size: .small,
                userId: post.author.id
            )

            Text(post.author.displayName)
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(post.createdAt.relativeString)
                .font(.system(size: 10))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
                .lineLimit(1)
        }
    }

    private func captionSection(_ caption: String) -> some View {
        Text(caption)
            .font(SplickTheme.Typography.body)
            .foregroundStyle(SplickTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(4)
            .padding(SplickTheme.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: Self.sectionCornerRadius, style: .continuous)
                    .fill(SplickTheme.Colors.secondaryBackground.opacity(0.65))
            }
            .clipShape(
                RoundedRectangle(cornerRadius: Self.sectionCornerRadius, style: .continuous)
            )
    }

    private var hasTaggedContent: Bool {
        if let groupName = post.companionGroupName, !groupName.isEmpty { return true }
        return !post.companions.isEmpty
    }

    private var taggedSection: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 10))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)

            taggedSummaryLabel

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: Self.sectionCornerRadius, style: .continuous)
                .fill(SplickTheme.Colors.secondaryBackground.opacity(0.65))
        }
        .clipShape(
            RoundedRectangle(cornerRadius: Self.sectionCornerRadius, style: .continuous)
        )
    }

    @ViewBuilder
    private var taggedSummaryLabel: some View {
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

    private var mediaPreview: some View {
        let firstMedia = post.displayMediaItems.first
        let mediaShape = RoundedRectangle(cornerRadius: Self.mediaCornerRadius, style: .continuous)

        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GridThumbnailImage(
                    url: firstMedia?.thumbnailURL
                        ?? firstMedia?.mediaURL
                        ?? post.thumbnailURL
                        ?? post.imageURL,
                    thumbnailWidth: 720
                ) {
                    SplickTheme.Colors.tertiaryBackground
                }
            }
            .overlay(alignment: .topTrailing) {
                if post.hasMultipleMedia {
                    Image(systemName: "square.fill.on.square.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(SplickTheme.Spacing.sm)
                } else if post.mediaType == .video {
                    Image(systemName: "play.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(SplickTheme.Spacing.sm)
                }
            }
            .clipShape(mediaShape)
            .contentShape(mediaShape)
    }

    private var normalizedCaption: String? {
        guard let caption = post.caption?.trimmingCharacters(in: .whitespacesAndNewlines),
              !caption.isEmpty else { return nil }
        return caption
    }

    private func dismissAnimated(completion: @escaping () -> Void) {
        guard !isDismissing else { return }
        isDismissing = true
        withAnimation(.easeOut(duration: 0.2)) {
            isRevealed = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            completion()
        }
    }
}
