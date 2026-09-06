import SwiftUI
import AVFoundation
import UIKit
import DesignSystem

/// Still preview for feed videos: remote thumbnail when available, otherwise the first decoded frame.
struct FeedVideoPosterView: View {
    let posterURL: URL?
    let videoURL: URL
    var displayHeight: CGFloat = FeedMediaLayout.defaultHeight

    @State private var generatedFrame: UIImage?
    @State private var loadFailed = false

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
                        if let generatedFrame {
                            Image(uiImage: generatedFrame).resizable().scaledToFill()
                        } else {
                            placeholder
                        }
                    @unknown default:
                        placeholder
                    }
                }
            } else if let generatedFrame {
                Image(uiImage: generatedFrame)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: videoURL) {
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
        SkeletonBone(
            height: displayHeight,
            shape: .rectangle(cornerRadius: 0)
        )
    }

    private func ensureFirstFrameIfNeeded() async {
        if remoteImageURL != nil, generatedFrame != nil { return }
        if let cached = await FeedVideoFirstFrameCache.shared.image(for: videoURL) {
            generatedFrame = cached
            return
        }
        guard let frame = await FeedVideoFirstFrameCache.shared.generate(for: videoURL) else {
            loadFailed = true
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
        guard memory.count > 48 else { return }
        let dropCount = memory.count - 32
        for key in memory.keys.prefix(dropCount) {
            memory.removeValue(forKey: key)
        }
    }

    private static func makeFirstFrame(url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(
            width: FeedMediaLayout.decodeMaxPixelSide,
            height: FeedMediaLayout.decodeMaxPixelSide
        )
        do {
            let cgImage = try await generator.image(at: .zero).image
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}
