import Foundation
import SplickDomain

/// In-memory LRU cache of recently opened chat threads so reopen can paint instantly
/// before the network reconcile finishes. Also persists entries under Application Support.
@MainActor
public final class MessageThreadCache {
    public struct Entry: Equatable, Sendable, Codable {
        public let messages: [ChatMessage]
        public let highestLoadedPage: Int
        public let hasMoreMessages: Bool

        public init(messages: [ChatMessage], highestLoadedPage: Int, hasMoreMessages: Bool) {
            self.messages = messages
            self.highestLoadedPage = highestLoadedPage
            self.hasMoreMessages = hasMoreMessages
        }
    }

    private let capacity: Int
    private var order: [UUID] = []
    private var storage: [UUID: Entry] = [:]
    private let diskDirectory: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init(capacity: Int = 5, diskDirectory: URL? = nil) {
        self.capacity = max(1, capacity)
        if let diskDirectory {
            self.diskDirectory = diskDirectory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.diskDirectory = support
                .appendingPathComponent("Splick", isDirectory: true)
                .appendingPathComponent("message-cache", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.diskDirectory, withIntermediateDirectories: true)
    }

    public func entry(for conversationId: UUID) -> Entry? {
        if let entry = storage[conversationId] {
            touch(conversationId)
            return entry
        }
        if let diskEntry = loadFromDisk(conversationId) {
            storage[conversationId] = diskEntry
            touch(conversationId)
            evictIfNeeded()
            return diskEntry
        }
        return nil
    }

    public func store(
        conversationId: UUID,
        messages: [ChatMessage],
        highestLoadedPage: Int,
        hasMoreMessages: Bool
    ) {
        let entry = Entry(
            messages: messages,
            highestLoadedPage: highestLoadedPage,
            hasMoreMessages: hasMoreMessages
        )
        storage[conversationId] = entry
        touch(conversationId)
        evictIfNeeded()
        persistToDisk(conversationId, entry: entry)
    }

    public func remove(conversationId: UUID) {
        storage.removeValue(forKey: conversationId)
        order.removeAll { $0 == conversationId }
        let url = diskURL(for: conversationId)
        try? FileManager.default.removeItem(at: url)
    }

    public func removeAll() {
        storage.removeAll()
        order.removeAll()
        try? FileManager.default.removeItem(at: diskDirectory)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }

    private func touch(_ conversationId: UUID) {
        order.removeAll { $0 == conversationId }
        order.append(conversationId)
    }

    private func evictIfNeeded() {
        while order.count > capacity {
            let oldest = order.removeFirst()
            storage.removeValue(forKey: oldest)
            // Keep disk copy so reopen after eviction can still warm from disk.
        }
    }

    private func diskURL(for conversationId: UUID) -> URL {
        diskDirectory.appendingPathComponent("\(conversationId.uuidString).json")
    }

    private func persistToDisk(_ conversationId: UUID, entry: Entry) {
        guard let data = try? encoder.encode(entry) else { return }
        try? data.write(to: diskURL(for: conversationId), options: .atomic)
    }

    private func loadFromDisk(_ conversationId: UUID) -> Entry? {
        let url = diskURL(for: conversationId)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(Entry.self, from: data)
    }
}
