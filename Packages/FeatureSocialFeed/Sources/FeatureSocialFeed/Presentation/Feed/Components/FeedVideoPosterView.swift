import SwiftUI
import UIKit
import DesignSystem

/// Still preview for feed videos: remote thumbnail when available, otherwise a light first-frame decode.
struct FeedVideoPosterView: View {
    let posterURL: URL?
    let videoURL: URL
    var displayHeight: CGFloat = FeedMediaLayout.defaultHeight

    @State private var generatedFrame: UIImage?

    private var remoteImageURL: URL? {
        VideoPosterURL.usableImageURL(posterURL, videoURL: videoURL)
    }

    var body: some View {
        Group {
            if let remoteImageURL {
                RemoteImage(
                    url: remoteImageURL,
                    maxPixelSize: FeedMediaLayout.feedMediaMaxDecodePixelSize(
                        displayHeight: displayHeight
                    )
                ) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        generatedOrPlaceholder
                    case .empty:
                        generatedOrPlaceholder
                    @unknown default:
                        generatedOrPlaceholder
                    }
                }
            } else {
                generatedOrPlaceholder
            }
        }
        .task(id: "\(videoURL.absoluteString)|\(remoteImageURL?.absoluteString ?? "")") {
            // Skip AVAsset first-frame decode when a real image poster exists — concurrent
            // AVURLAsset + AVPlayer on the same URL spam PlayerRemoteXPC errors in console.
            guard remoteImageURL == nil else { return }
            await ensureFirstFrameIfNeeded()
        }
    }

    @ViewBuilder
    private var generatedOrPlaceholder: some View {
        if let generatedFrame {
            Image(uiImage: generatedFrame)
                .resizable()
                .scaledToFill()
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        // Soft bone — not pure black — while the first frame is decoding.
        Color(uiColor: .secondarySystemFill)
    }

    private func ensureFirstFrameIfNeeded() async {
        if let cached = await VideoFirstFrameCache.shared.image(for: videoURL) {
            generatedFrame = cached
            return
        }
        guard let frame = await VideoFirstFrameCache.shared.generate(for: videoURL) else {
            return
        }
        generatedFrame = frame
    }
}

/// Compatibility aliases used by older call sites / tests.
enum FeedVideoPoster {
    static func usableImageURL(_ posterURL: URL?, videoURL: URL) -> URL? {
        VideoPosterURL.usableImageURL(posterURL, videoURL: videoURL)
    }
}

typealias FeedVideoFirstFrameCache = VideoFirstFrameCache
