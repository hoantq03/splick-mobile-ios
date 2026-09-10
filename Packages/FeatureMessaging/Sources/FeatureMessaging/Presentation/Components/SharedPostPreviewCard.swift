import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct SharedPostPreviewCard: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.fetchSharedPost) private var fetchSharedPost
    @Environment(\.openLinkedPost) private var openLinkedPost

    let postId: UUID
    let isOutgoing: Bool
    var enabled: Bool = true
    var maxWidth: CGFloat = MessageThreadRowLayout.mediaFallbackMaxWidth

    @State private var post: Post?
    @State private var loadFailed = false

    private static let mediaHeight: CGFloat = 148

    var body: some View {
        content
            .frame(maxWidth: maxWidth, alignment: .leading)
            .padding(8)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: MessageThreadRowLayout.quoteCornerRadius, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture {
                guard enabled else { return }
                openLinkedPost?(postId, false)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(languageService.text(.postPreviewAccessibility))
            .accessibilityAddTraits(.isButton)
            .task(id: postId) {
                await load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let post {
            readyColumn(post)
        } else if loadFailed {
            unavailableColumn
        } else {
            loadingColumn
        }
    }

    private func readyColumn(_ post: Post) -> some View {
        let preview = SharedPostPreviewMedia.resolve(from: post)
        let caption = post.caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayCaption = (caption?.isEmpty == false)
            ? caption!
            : languageService.text(.feedShareFallbackCaption)

        return VStack(alignment: .leading, spacing: 8) {
            mediaPreview(url: preview.imageURL, isVideo: preview.isVideo)
            VStack(alignment: .leading, spacing: 2) {
                Text(languageService.text(.messagingSharedPostLabel))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(labelColor)
                Text(post.author.preferredName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                Text(displayCaption)
                    .font(.system(size: 13))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(2)
            }
        }
    }

    private var loadingColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.12))
                ProgressView()
                    .tint(titleColor.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.mediaHeight)
            VStack(alignment: .leading, spacing: 4) {
                Text(languageService.text(.messagingSharedPostLabel))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(labelColor)
                Text(languageService.text(.feedShareFallbackCaption))
                    .font(.system(size: 13))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(2)
            }
        }
    }

    private var unavailableColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.12))
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(titleColor.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.mediaHeight)
            VStack(alignment: .leading, spacing: 2) {
                Text(languageService.text(.messagingSharedPostLabel))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(labelColor)
                Text(languageService.text(.messagingSharedPostUnavailable))
                    .font(.system(size: 13))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(2)
            }
        }
    }

    private func mediaPreview(url: URL?, isVideo: Bool) -> some View {
        ZStack {
            GridThumbnailImage(url: url, thumbnailWidth: 480) {
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.18))
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.mediaHeight)
            .clipped()

            if isVideo {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.45), in: Circle())
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.mediaHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var cardBackground: Color {
        if isOutgoing {
            return Color.white.opacity(0.16)
        }
        return SplickTheme.Colors.cardBackground.opacity(0.92)
    }

    private var titleColor: Color {
        isOutgoing ? .white : SplickTheme.Colors.textPrimary
    }

    private var subtitleColor: Color {
        isOutgoing ? Color.white.opacity(0.82) : SplickTheme.Colors.textSecondary
    }

    private var labelColor: Color {
        isOutgoing ? Color.white.opacity(0.72) : SplickTheme.Colors.primaryGradientStart
    }

    private func load() async {
        loadFailed = false
        guard let fetchSharedPost else {
            loadFailed = true
            return
        }
        do {
            post = try await fetchSharedPost(postId)
        } catch {
            post = nil
            loadFailed = true
        }
    }
}

/// Still frame for a shared-post card: first image, or video poster — never the raw video file.
enum SharedPostPreviewMedia {
    struct Resolved: Equatable {
        let imageURL: URL?
        let isVideo: Bool
    }

    static func resolve(from post: Post) -> Resolved {
        let first = post.displayMediaItems.first
        let isVideo = (first?.mediaType ?? post.mediaType) == .video
        if let thumb = first?.thumbnailURL ?? post.thumbnailURL {
            return Resolved(imageURL: thumb, isVideo: isVideo)
        }
        if !isVideo {
            let imageURL = first?.mediaURL ?? post.imageURL
            return Resolved(imageURL: imageURL, isVideo: false)
        }
        return Resolved(imageURL: nil, isVideo: true)
    }
}
