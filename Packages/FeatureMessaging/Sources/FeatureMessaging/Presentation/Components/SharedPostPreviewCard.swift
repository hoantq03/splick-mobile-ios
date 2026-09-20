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
            SharedPostMediaPreview(
                imageURL: preview.imageURL,
                videoURL: preview.videoURL,
                isVideo: preview.isVideo,
                height: Self.mediaHeight
            )
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
                SplickSpinner(usesBrandColors: false)
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

/// Still preview for shared posts: remote image when available, otherwise first video frame.
private struct SharedPostMediaPreview: View {
    let imageURL: URL?
    let videoURL: URL?
    let isVideo: Bool
    let height: CGFloat

    @State private var generatedFrame: UIImage?
    @State private var isDecodingFrame = false

    private var remoteImageURL: URL? {
        if let videoURL {
            return VideoPosterURL.usableImageURL(imageURL, videoURL: videoURL)
                ?? (isVideo ? nil : imageURL)
        }
        return imageURL
    }

    var body: some View {
        ZStack {
            mediaLayer
            if isVideo {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.45), in: Circle())
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task(id: taskKey) {
            await ensureFirstFrameIfNeeded()
        }
    }

    private var taskKey: String {
        "\(remoteImageURL?.absoluteString ?? "")|\(videoURL?.absoluteString ?? "")|\(isVideo)"
    }

    @ViewBuilder
    private var mediaLayer: some View {
        if let remoteImageURL {
            GridThumbnailImage(url: remoteImageURL, thumbnailWidth: 480) {
                generatedOrPlaceholder
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
        } else {
            generatedOrPlaceholder
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
    }

    @ViewBuilder
    private var generatedOrPlaceholder: some View {
        if let generatedFrame {
            Image(uiImage: generatedFrame)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if isDecodingFrame {
            ZStack {
                Color.black.opacity(0.18)
                SplickSpinner(usesBrandColors: false)
            }
        } else {
            Image(systemName: "photo")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.18))
        }
    }

    private func ensureFirstFrameIfNeeded() async {
        generatedFrame = nil
        guard isVideo, let videoURL else {
            isDecodingFrame = false
            return
        }
        // Prefer a real image poster; only decode the first frame when needed.
        if remoteImageURL != nil {
            isDecodingFrame = false
            return
        }
        isDecodingFrame = true
        defer { isDecodingFrame = false }
        if let cached = await VideoFirstFrameCache.shared.image(for: videoURL) {
            generatedFrame = cached
            return
        }
        generatedFrame = await VideoFirstFrameCache.shared.generate(for: videoURL)
    }
}

/// Still frame for a shared-post card: first image, or video poster / first frame — never the raw video file.
enum SharedPostPreviewMedia {
    struct Resolved: Equatable {
        let imageURL: URL?
        let videoURL: URL?
        let isVideo: Bool
    }

    static func resolve(from post: Post) -> Resolved {
        let first = post.displayMediaItems.first
        let isVideo = (first?.mediaType ?? post.mediaType) == .video
        let thumbnail = first?.thumbnailURL ?? post.thumbnailURL
        let mediaURL = first?.mediaURL ?? (isVideo ? post.videoURL : nil) ?? post.imageURL
        if let thumbnail {
            return Resolved(
                imageURL: thumbnail,
                videoURL: isVideo ? mediaURL : nil,
                isVideo: isVideo
            )
        }
        if !isVideo {
            return Resolved(imageURL: mediaURL, videoURL: nil, isVideo: false)
        }
        return Resolved(imageURL: nil, videoURL: mediaURL, isVideo: true)
    }
}
