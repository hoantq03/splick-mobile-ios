import SwiftUI
import DesignSystem
import SplickDomain

struct PostMediaView: View {
    let post: Post
    /// Called with the index of the tapped item. Nil = not tappable.
    var onTap: ((Int) -> Void)?

    @State private var selectedIndex = 0

    private var items: [PostMediaItem] {
        post.displayMediaItems
    }

    var body: some View {
        Group {
            if items.count <= 1, let item = items.first {
                mediaItemView(item)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(0) }
            } else {
                multiMediaCarousel
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
    }

    private var multiMediaCarousel: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    mediaItemView(item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 350)
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

    @ViewBuilder
    private func mediaItemView(_ item: PostMediaItem) -> some View {
        switch item.mediaType {
        case .image:
            imageContent(for: item)
        case .video:
            videoContent(for: item)
        }
    }

    private func imageContent(for item: PostMediaItem) -> some View {
        RemoteImage(url: item.thumbnailURL ?? item.mediaURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: 350)
                    .clipped()
            case .failure:
                mediaPlaceholder(icon: "photo")
            default:
                mediaPlaceholder(icon: nil, showProgress: true)
            }
        }
    }

    private func videoContent(for item: PostMediaItem) -> some View {
        Group {
            FeedInlineVideoPlayer(
                postId: post.id,
                url: item.mediaURL,
                posterURL: item.thumbnailURL ?? item.mediaURL,
                durationSeconds: item.durationSeconds
            )
        }
        .frame(maxHeight: 350)
    }

    private func mediaPlaceholder(icon: String?, showProgress: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small)
            .fill(SplickTheme.Colors.secondaryBackground)
            .frame(height: 250)
            .overlay {
                if showProgress {
                    ProgressView()
                } else if let icon {
                    Image(systemName: icon)
                        .font(.largeTitle)
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
            }
    }
}
