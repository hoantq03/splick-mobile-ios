import Foundation
import SplickDomain

/// In-memory LRU cache of recently opened chat threads so reopen can paint instantly
/// before the network reconcile finishes.
@MainActor
public final class MessageThreadCache {
    public struct Entry: Equatable, Sendable {
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

    public init(capacity: Int = 5) {
        self.capacity = max(1, capacity)
    }

    public func entry(for conversationId: UUID) -> Entry? {
        guard let entry = storage[conversationId] else { return nil }
        touch(conversationId)
        return entry
    }

    public func store(
        conversationId: UUID,
        messages: [ChatMessage],
        highestLoadedPage: Int,
        hasMoreMessages: Bool
    ) {
        storage[conversationId] = Entry(
            messages: messages,
            highestLoadedPage: highestLoadedPage,
            hasMoreMessages: hasMoreMessages
        )
        touch(conversationId)
        evictIfNeeded()
    }

    public func remove(conversationId: UUID) {
        storage.removeValue(forKey: conversationId)
        order.removeAll { $0 == conversationId }
    }

    public func removeAll() {
        storage.removeAll()
        order.removeAll()
    }

    private func touch(_ conversationId: UUID) {
        order.removeAll { $0 == conversationId }
        order.append(conversationId)
    }

    private func evictIfNeeded() {
        while order.count > capacity {
            let oldest = order.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }
}
