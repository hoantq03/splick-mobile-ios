import Foundation
import Nuke

/// Configures the shared Nuke pipeline once at app launch (disk + memory cache).
public enum ImagePipelineConfigurator {
    private static let lock = NSLock()
    private static var isConfigured = false

    /// 500 MB on-disk cache for feed/album thumbnails and full images.
    private static let diskCacheSize = 500 * 1024 * 1024

    public static func configureIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !isConfigured else { return }
        isConfigured = true

        ImagePipeline.shared = ImagePipeline(
            configuration: .withDataCache(
                name: "com.splick.image-cache",
                sizeLimit: diskCacheSize
            )
        )
    }
}
