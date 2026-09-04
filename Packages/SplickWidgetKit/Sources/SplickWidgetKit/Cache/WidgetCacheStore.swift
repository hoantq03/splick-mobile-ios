import Foundation

public enum WidgetCacheError: Error {
    case appGroupUnavailable
    case encodingFailed
    case decodingFailed
}

public final class WidgetCacheStore: Sendable {
    public static let shared = WidgetCacheStore()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func write<T: Encodable>(_ value: T, to filename: String) throws {
        let data = try encoder.encode(value)
        try ensureCacheDirectory()
        guard let url = fileURL(for: filename) else {
            throw WidgetCacheError.appGroupUnavailable
        }
        try data.write(to: url, options: [.atomic])
    }

    public func read<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        guard let url = fileURL(for: filename),
              fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decoder.decode(type, from: data)
    }

    public func fileURL(for filename: String) -> URL? {
        WidgetAppGroup.cacheDirectoryURL?.appendingPathComponent(filename)
    }

    private func ensureCacheDirectory() throws {
        guard let directory = WidgetAppGroup.cacheDirectoryURL else {
            throw WidgetCacheError.appGroupUnavailable
        }
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
