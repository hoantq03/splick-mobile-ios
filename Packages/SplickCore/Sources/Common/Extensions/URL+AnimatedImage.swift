import Foundation

public extension URL {
    /// Heuristic for remote GIF/WebP stickers (e.g. KLIPY `media_formats`).
    var isLikelyAnimatedImage: Bool {
        let ext = pathExtension.lowercased()
        if ext == "gif" || ext == "webp" {
            return true
        }

        let lowercased = absoluteString.lowercased()
        if lowercased.contains(".gif") {
            return true
        }

        return lowercased.contains("media_formats") && lowercased.contains("gif")
    }
}
