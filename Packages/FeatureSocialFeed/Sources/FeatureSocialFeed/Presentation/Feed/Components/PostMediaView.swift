import SwiftUI
import DesignSystem
import SplickDomain

private struct PostMediaContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

struct PostMediaView: View {
    let post: Post
    @Binding var selectedIndex: Int
    /// Called with the index of the tapped item. Nil = not tappable.
    var onTap: ((Int) -> Void)?

    @State private var containerWidth: CGFloat = FeedMediaLayout.estimatedCardContentWidth

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
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PostMediaContainerWidthKey.self,
                    value: proxy.size.width
                )
            }
        )
        .onPreferenceChange(PostMediaContainerWidthKey.self) { width in
            guard width > 0 else { return }
            containerWidth = width
        }
        .clipShape(RoundedRectangle(cornerRadius: FeedMediaLayout.cornerRadius, style: .continuous))
        .onChange(of: post.id) { _ in
            selectedIndex = min(selectedIndex, max(items.count - 1, 0))
        }
    }

    private var multiMediaCarousel: some View {
        let carouselHeight = carouselHeight(for: selectedIndex)
        return ZStack(alignment: .topTrailing) {
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

            Text("\(selectedIndex + 1)/\(items.count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(10)
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
        let fillFrame = FeedMediaLayout.shouldFillFrame(for: item, containerWidth: width)

        return RemoteImage(
            url: item.thumbnailURL ?? item.mediaURL,
            maxPixelSize: FeedMediaLayout.feedMediaMaxDecodePixelSize(
                containerWidth: width,
                displayHeight: height
            )
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
    }

    private func mediaPlaceholder(
        icon: String?,
        showProgress: Bool = false,
        height: CGFloat = FeedMediaLayout.placeholderHeight
    ) -> some View {
        SplickTheme.Colors.secondaryBackground
            .frame(width: resolvedWidth, height: height)
            .overlay {
                if showProgress {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.regular)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.largeTitle)
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
            }
    }
}
