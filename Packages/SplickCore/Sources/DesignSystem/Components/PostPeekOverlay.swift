import SwiftUI
import AVFoundation
import Common
import Localization
import SplickDomain

public struct PostPeekOverlay: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.currentUserSummary) private var currentUserSummary

    private let post: Post
    private let mediaIndex: Int
    private let onDismiss: () -> Void
    private let onOpen: () -> Void

    @State private var isRevealed = false
    @State private var isDismissing = false

    private static let mediaCornerRadius = SplickTheme.CornerRadius.inset
    private static let sectionCornerRadius = SplickTheme.CornerRadius.inset

    public init(
        post: Post,
        mediaIndex: Int = 0,
        onDismiss: @escaping () -> Void,
        onOpen: @escaping () -> Void
    ) {
        self.post = post
        self.mediaIndex = mediaIndex
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
        .overlay(alignment: .topTrailing) {
            if post.isEdited {
                FeedPostEditedBadge()
            }
        }
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

            CompanionsSummaryText(
                companions: post.companions,
                groupName: post.companionGroupName,
                currentUserId: currentUserSummary?.id,
                font: .system(size: 11),
                color: SplickTheme.Colors.textSecondary
            )

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

    private var mediaPreview: some View {
        let media = previewMedia
        let isVideo = media?.mediaType == .video
        let videoURL = isVideo ? media?.mediaURL : nil
        let posterURL = media?.thumbnailURL
            ?? (isVideo ? post.thumbnailURL : nil)
            ?? (isVideo ? nil : media?.mediaURL)
            ?? post.imageURL
        let mediaShape = RoundedRectangle(cornerRadius: Self.mediaCornerRadius, style: .continuous)

        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GridThumbnailImage(url: posterURL, thumbnailWidth: 720) {
                    SplickTheme.Colors.tertiaryBackground
                }
            }
            .overlay {
                if let videoURL {
                    PeekLoopingVideo(url: videoURL)
                }
            }
            .overlay(alignment: .topTrailing) {
                if post.hasMultipleMedia {
                    Image(systemName: "square.fill.on.square.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(SplickTheme.Spacing.sm)
                }
            }
            .clipShape(mediaShape)
            .contentShape(mediaShape)
    }

    private var previewMedia: PostMediaItem? {
        let items = post.displayMediaItems
        if items.indices.contains(mediaIndex) {
            return items[mediaIndex]
        }
        return items.first
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

/// Muted looping preview. Touches pass through so the card tap still opens the post.
private struct PeekLoopingVideo: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PeekLoopingVideoView {
        let view = PeekLoopingVideoView()
        context.coordinator.attach(url: url, to: view)
        return view
    }

    func updateUIView(_ view: PeekLoopingVideoView, context: Context) {
        context.coordinator.attach(url: url, to: view)
    }

    static func dismantleUIView(_ uiView: PeekLoopingVideoView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        private var player: AVPlayer?
        private var endObserver: NSObjectProtocol?
        private var loadedURL: URL?

        func attach(url: URL, to view: PeekLoopingVideoView) {
            if loadedURL == url {
                view.playerLayer.player = player
                player?.play()
                return
            }
            stop()
            loadedURL = url
            let item = AVPlayerItem(url: url)
            item.preferredForwardBufferDuration = 1
            let player = AVPlayer(playerItem: item)
            player.isMuted = true
            player.actionAtItemEnd = .none
            player.automaticallyWaitsToMinimizeStalling = false
            self.player = player
            view.playerLayer.player = player
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
            player.play()
        }

        func stop() {
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
                self.endObserver = nil
            }
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
            loadedURL = nil
        }
    }
}

private final class PeekLoopingVideoView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
