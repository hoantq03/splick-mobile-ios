import SwiftUI
import DesignSystem
import SplickDomain

struct PostMediaView: View {
    let post: Post
    @Binding var selectedIndex: Int
    /// Called with the index of the tapped item. Nil = not tappable.
    var onTap: ((Int) -> Void)?
    /// When true, the parent should lift z-index and relax clipping so pinch zoom can escape the card.
    @Binding var isPinchZooming: Bool

    @State private var containerWidth: CGFloat = FeedMediaLayout.estimatedCardContentWidth

    init(
        post: Post,
        selectedIndex: Binding<Int>,
        onTap: ((Int) -> Void)? = nil,
        isPinchZooming: Binding<Bool> = .constant(false)
    ) {
        self.post = post
        self._selectedIndex = selectedIndex
        self.onTap = onTap
        self._isPinchZooming = isPinchZooming
    }

    private var items: [PostMediaItem] {
        post.displayMediaItems
    }

    private var resolvedWidth: CGFloat {
        containerWidth > 0 ? containerWidth : FeedMediaLayout.estimatedCardContentWidth
    }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyView()
            } else if items.count == 1 {
                mediaItemView(items[0], fixedHeight: nil)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(0) }
            } else {
                multiMediaCarousel
            }
        }
        .frame(maxWidth: .infinity)
        .modifier(PostMediaWidthReader(containerWidth: $containerWidth))
        .modifier(PostMediaClipModifier(isPinchZooming: isPinchZooming))
        .onChange(of: post.id) { _ in
            selectedIndex = min(selectedIndex, max(items.count - 1, 0))
            if isPinchZooming {
                isPinchZooming = false
                FeedScrollLock.setLocked(false)
            }
        }
    }

    private var multiMediaCarousel: some View {
        let carouselHeight = carouselHeight(for: selectedIndex)
        return ZStack(alignment: .topTrailing) {
            if #available(iOS 17.0, *) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            mediaItemView(item, fixedHeight: carouselHeight)
                                .frame(width: resolvedWidth)
                                .id(index)
                                .onAppear { selectedIndex = index }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .frame(maxWidth: .infinity)
                .frame(height: carouselHeight)
                .contentShape(Rectangle())
                .onTapGesture { onTap?(selectedIndex) }
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        mediaItemView(item, fixedHeight: carouselHeight)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(maxWidth: .infinity)
                .frame(height: carouselHeight)
                .contentShape(Rectangle())
                .onTapGesture { onTap?(selectedIndex) }
            }

            Text("\(selectedIndex + 1)/\(items.count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(10)
                .opacity(isPinchZooming ? 0 : 1)
                .allowsHitTesting(false)
        }
    }

    private func carouselHeight(for index: Int) -> CGFloat {
        guard items.indices.contains(index) else {
            return FeedMediaLayout.defaultHeight
        }
        return FeedMediaLayout.displayHeight(for: items[index], containerWidth: resolvedWidth)
    }

    @ViewBuilder
    private func mediaItemView(_ item: PostMediaItem, fixedHeight: CGFloat?) -> some View {
        switch item.mediaType {
        case .image:
            imageContent(for: item, fixedHeight: fixedHeight)
        case .video:
            videoContent(for: item, fixedHeight: fixedHeight)
        }
    }

    private func imageContent(for item: PostMediaItem, fixedHeight: CGFloat?) -> some View {
        let width = resolvedWidth
        let height = fixedHeight ?? FeedMediaLayout.displayHeight(for: item, containerWidth: width)
        // Carousel pages share one height — always fill to avoid letterboxed thin strips
        // when metadata aspect and decoded pixels disagree (EXIF / bad thumbnail).
        let fillFrame = fixedHeight != nil
            || FeedMediaLayout.shouldFillFrame(for: item, containerWidth: width)
        // Prefer full media URL so pinch zoom stays sharp past the feed decode budget.
        let imageURL = item.mediaURL
        // Cap decode at FeedMediaLayout budget — do not floor at 1280 (that forces
        // oversized RGBA buffers and triggers CVPixelBufferCreate -6680 for 1512×2016 sources).
        let decodeSide = FeedMediaLayout.feedMediaMaxDecodePixelSize(
            containerWidth: width,
            displayHeight: height
        )

        return RemoteImage(
            url: imageURL,
            maxPixelSize: decodeSide
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: fillFrame ? .fill : .fit)
                    .frame(width: width, height: height)
                    .clipped()
            case .failure:
                mediaPlaceholder(icon: "photo", height: height)
            default:
                mediaPlaceholder(icon: nil, showProgress: true, height: height)
            }
        }
        .frame(width: width, height: height)
        .frame(maxWidth: .infinity)
        .feedMediaPinchZoom(isActive: $isPinchZooming)
    }

    private func videoContent(for item: PostMediaItem, fixedHeight: CGFloat?) -> some View {
        let width = resolvedWidth
        let height = fixedHeight ?? FeedMediaLayout.displayHeight(for: item, containerWidth: width)
        return FeedInlineVideoPlayer(
            postId: post.id,
            url: item.mediaURL,
            posterURL: item.thumbnailURL ?? item.mediaURL,
            durationSeconds: item.durationSeconds,
            displayHeight: height
        )
        .frame(width: width, height: height)
        .frame(maxWidth: .infinity)
    }

    private func mediaPlaceholder(
        icon: String?,
        showProgress: Bool = false,
        height: CGFloat = FeedMediaLayout.placeholderHeight
    ) -> some View {
        Group {
            if showProgress {
                // Static bone (no per-cell TimelineView) — avoids N shimmer clocks while scrolling.
                SkeletonBone(
                    height: height,
                    shape: .rectangle(cornerRadius: FeedMediaLayout.cornerRadius)
                )
                .frame(width: resolvedWidth, height: height)
            } else {
                SplickTheme.Colors.secondaryBackground
                    .frame(width: resolvedWidth, height: height)
                    .overlay {
                        if let icon {
                            Image(systemName: icon)
                                .font(.largeTitle)
                                .foregroundStyle(SplickTheme.Colors.textTertiary)
                        }
                    }
            }
        }
    }
}

/// Keeps rounded clip for idle media; removes it while pinch-zooming so the image can grow.
private struct PostMediaClipModifier: ViewModifier {
    let isPinchZooming: Bool

    func body(content: Content) -> some View {
        if isPinchZooming {
            content
        } else {
            content.clipShape(
                RoundedRectangle(cornerRadius: FeedMediaLayout.cornerRadius, style: .continuous)
            )
        }
    }
}

private struct PostMediaWidthReader: ViewModifier {
    @Binding var containerWidth: CGFloat

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { apply(proxy.size.width) }
                    .onChange(of: proxy.size.width) { apply($0) }
            }
        }
    }

    private func apply(_ width: CGFloat) {
        let minimumCredibleWidth = min(FeedMediaLayout.estimatedCardContentWidth * 0.55, 180)
        guard width >= minimumCredibleWidth, abs(width - containerWidth) > 1 else { return }
        containerWidth = width
    }
}
