import SwiftUI
import AVFoundation
import UIKit
import DesignSystem

/// Still preview for feed videos: remote thumbnail when available, otherwise a light first-frame decode.
struct FeedVideoPosterView: View {
    let posterURL: URL?
    let videoURL: URL
    var displayHeight: CGFloat = FeedMediaLayout.defaultHeight

    @State private var generatedFrame: UIImage?

    private var remoteImageURL: URL? {
        Self.usableImageURL(posterURL, videoURL: videoURL)
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
        if let cached = await FeedVideoFirstFrameCache.shared.image(for: videoURL) {
            generatedFrame = cached
            return
        }
        guard let frame = await FeedVideoFirstFrameCache.shared.generate(for: videoURL) else {
            return
        }
        generatedFrame = frame
    }

    /// Thumbnails that are actual images — not the raw video file URL.
    static func usableImageURL(_ posterURL: URL?, videoURL: URL) -> URL? {
        guard let posterURL else { return nil }
        if posterURL.absoluteString == videoURL.absoluteString { return nil }
        let ext = posterURL.pathExtension.lowercased()
        if ["mp4", "mov", "m4v", "webm", "m3u8"].contains(ext) { return nil }
        return posterURL
    }
}

actor FeedVideoFirstFrameCache {
    static let shared = FeedVideoFirstFrameCache()

    /// Keep first-frame decode cheap — posters are only placeholders until autoplay starts.
    private static let maxDecodeSide: CGFloat = 384

    private var memory: [String: UIImage] = [:]
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    func image(for url: URL) -> UIImage? {
        memory[url.absoluteString]
    }

    func generate(for url: URL) async -> UIImage? {
        let key = url.absoluteString
        if let cached = memory[key] { return cached }
        if let existing = inFlight[key] {
            return await existing.value
        }
        let task = Task<UIImage?, Never> {
            await Self.makeFirstFrame(url: url)
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image {
            memory[key] = image
            trimIfNeeded()
        }
        return image
    }

    private func trimIfNeeded() {
        guard memory.count > 32 else { return }
        let dropCount = memory.count - 24
        for key in memory.keys.prefix(dropCount) {
            memory.removeValue(forKey: key)
        }
    }

    private static func makeFirstFrame(url: URL) async -> UIImage? {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxDecodeSide, height: maxDecodeSide)
            guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }.value
    }
}
