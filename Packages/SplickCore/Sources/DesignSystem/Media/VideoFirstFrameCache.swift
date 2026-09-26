import AVFoundation
import UIKit

/// Remote image poster only — never pass a raw video file URL to the image loader.
public enum VideoPosterURL {
    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "webm", "mkv", "m3u8"]

    public static func usableImageURL(_ posterURL: URL?, videoURL: URL) -> URL? {
        guard let posterURL else { return nil }
        if posterURL.absoluteString == videoURL.absoluteString { return nil }
        let ext = posterURL.pathExtension.lowercased()
        if videoExtensions.contains(ext) { return nil }
        return posterURL
    }
}

/// Extracts and caches the first video frame for poster placeholders.
public actor VideoFirstFrameCache {
    public static let shared = VideoFirstFrameCache()

    /// Keep first-frame decode cheap — posters are only placeholders.
    private static let maxDecodeSide: CGFloat = 384

    private var memory: [String: UIImage] = [:]
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    public func image(for url: URL) -> UIImage? {
        memory[url.absoluteString]
    }

    public func generate(for url: URL) async -> UIImage? {
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
