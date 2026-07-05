import SwiftUI
import DesignSystem
import SplickDomain

struct PostMediaView: View {
    let post: Post
    @Binding var selectedIndex: Int
    /// Called with the index of the tapped item. Nil = not tappable.
    var onTap: ((Int) -> Void)?

    private var items: [PostMediaItem] {
        post.displayMediaItems
    }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyView()
            } else if items.count == 1 {
                mediaItemView(items[0])
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(0) }
            } else {
                multiMediaCarousel
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
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
            .frame(height: carouselHeight)
            .simultaneousGesture(
                TapGesture().onEnded { onTap?(selectedIndex) }
            )

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
        return FeedMediaLayout.displayHeight(for: items[index])
    }

    @ViewBuilder
    private func mediaItemView(_ item: PostMediaItem, fixedHeight: CGFloat? = nil) -> some View {
        switch item.mediaType {
        case .image:
            imageContent(for: item, fixedHeight: fixedHeight)
        case .video:
            videoContent(for: item, fixedHeight: fixedHeight)
        }
    }

    private func imageContent(for item: PostMediaItem, fixedHeight: CGFloat?) -> some View {
        let height = fixedHeight ?? FeedMediaLayout.displayHeight(for: item)
        let clamped = FeedMediaLayout.isHeightClamped(for: item)

        return RemoteImage(
            url: item.thumbnailURL ?? item.mediaURL,
            maxPixelDimensions: FeedMediaLayout.feedMediaMaxPixelSize
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: clamped ? .fill : .fit)
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
                    .clipped()
            case .failure:
                mediaPlaceholder(icon: "photo", height: height)
            default:
                mediaPlaceholder(icon: nil, showProgress: true, height: height)
            }
        }
    }

    private func videoContent(for item: PostMediaItem, fixedHeight: CGFloat?) -> some View {
        let height = fixedHeight ?? FeedMediaLayout.displayHeight(for: item)
        return Group {
            FeedInlineVideoPlayer(
                postId: post.id,
                url: item.mediaURL,
                posterURL: item.thumbnailURL ?? item.mediaURL,
                durationSeconds: item.durationSeconds,
                displayHeight: height
            )
        }
        .frame(height: height)
    }

    private func mediaPlaceholder(icon: String?, showProgress: Bool = false, height: CGFloat = FeedMediaLayout.placeholderHeight) -> some View {
        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small)
            .fill(SplickTheme.Colors.secondaryBackground)
            .frame(height: height)
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
