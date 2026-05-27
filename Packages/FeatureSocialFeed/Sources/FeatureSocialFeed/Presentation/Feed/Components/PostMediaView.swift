import SwiftUI
import DesignSystem
import SplickDomain

struct PostMediaView: View {
    let post: Post

    var body: some View {
        Group {
            switch post.mediaType {
            case .image:
                imageContent
            case .video:
                videoContent
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
    }

    private var imageContent: some View {
        RemoteImage(url: post.thumbnailURL ?? post.imageURL) { phase in
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

    private var videoContent: some View {
        Group {
            if let videoURL = post.videoURL {
                FeedInlineVideoPlayer(
                    postId: post.id,
                    url: videoURL,
                    posterURL: post.thumbnailURL ?? post.imageURL,
                    durationSeconds: post.videoDurationSeconds
                )
            } else {
                RemoteImage(url: post.thumbnailURL ?? post.imageURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 350)
                            .clipped()
                    } else {
                        mediaPlaceholder(icon: "video")
                    }
                }
            }
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
