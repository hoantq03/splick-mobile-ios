import Foundation
import Nuke
import UIKit

/// Configures the shared Nuke pipeline once at app launch (disk + memory cache).
public enum ImagePipelineConfigurator {
    private static let lock = NSLock()
    private static var isConfigured = false

    /// 500 MB on-disk cache for feed/album thumbnails and full images.
    private static let diskCacheSize = 500 * 1024 * 1024
    /// In-memory decoded image budget — avoids retaining full-resolution buffers for every visible cell.
    private static let memoryCacheCostLimit = 64 * 1024 * 1024

    public static func configureIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !isConfigured else { return }
        isConfigured = true

        var configuration = ImagePipeline.Configuration.withDataCache(
            name: "com.splick.image-cache",
            sizeLimit: diskCacheSize
        )
        configuration.imageCache = ImageCache(
            costLimit: memoryCacheCostLimit,
            countLimit: 300
        )

        ImagePipeline.shared = ImagePipeline(configuration: configuration)

        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            ImageCache.shared.removeAll()
        }
    }
}
