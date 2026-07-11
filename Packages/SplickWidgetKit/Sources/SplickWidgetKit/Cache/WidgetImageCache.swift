import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public enum WidgetTimelineReloader {
    public static func reloadAll() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public static func reload(_ kinds: String...) {
        #if canImport(WidgetKit)
        for kind in kinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
        #endif
    }
}

public final class WidgetImageCache: Sendable {
    public static let shared = WidgetImageCache()

    private let fileManager: FileManager
    private let session: URLSession

    public init(
        fileManager: FileManager = .default,
        session: URLSession = .shared
    ) {
        self.fileManager = fileManager
        self.session = session
    }

    @discardableResult
    public func cacheImage(from remoteURL: URL, filename: String) async -> String? {
        guard let directory = WidgetAppGroup.imageCacheDirectoryURL else { return nil }
        do {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let (data, response) = try await session.data(from: remoteURL)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return nil
            }
            let destination = directory.appendingPathComponent(filename)
            try data.write(to: destination, options: [.atomic])
            return filename
        } catch {
            return nil
        }
    }

    public func imageURL(for filename: String?) -> URL? {
        guard let filename, let directory = WidgetAppGroup.imageCacheDirectoryURL else { return nil }
        let url = directory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
}
