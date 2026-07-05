import Foundation

public struct DiskCacheEntry<T: Codable>: Codable {
    public let cachedAt: Date
    public let value: T

    public init(cachedAt: Date = Date(), value: T) {
        self.cachedAt = cachedAt
        self.value = value
    }
}

public actor DiskCache {
    public static let shared = DiskCache()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let directoryURL: URL

    public init(subdirectory: String = "DiskCache") {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directoryURL = base.appendingPathComponent(subdirectory, isDirectory: true)
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    public func read<T: Codable>(_ type: T.Type, key: String) -> T? {
        readEntry(type, key: key)?.value
    }

    public func readEntry<T: Codable>(_ type: T.Type, key: String) -> DiskCacheEntry<T>? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(DiskCacheEntry<T>.self, from: data)
    }

    public func write<T: Codable>(_ value: T, key: String) {
        let entry = DiskCacheEntry(value: value)
        guard let data = try? encoder.encode(entry) else { return }
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    public func remove(key: String) {
        try? fileManager.removeItem(at: fileURL(for: key))
    }

    private func fileURL(for key: String) -> URL {
        let safeName = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return directoryURL.appendingPathComponent("\(safeName).json")
    }
}
