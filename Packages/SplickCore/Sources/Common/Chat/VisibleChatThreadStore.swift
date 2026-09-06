import Foundation

/// Conversation currently on screen. Push banners for that thread are suppressed while the app is active.
public final class VisibleChatThreadStore: @unchecked Sendable {
    public static let shared = VisibleChatThreadStore()

    private let lock = NSLock()
    private var conversationId: UUID?

    public init() {}

    public func set(_ conversationId: UUID?) {
        lock.lock()
        self.conversationId = conversationId
        lock.unlock()
    }

    public func clearIfMatching(_ conversationId: UUID) {
        lock.lock()
        if self.conversationId == conversationId {
            self.conversationId = nil
        }
        lock.unlock()
    }

    public func matches(_ conversationId: UUID?) -> Bool {
        guard let conversationId else {
            return false
        }
        lock.lock()
        defer { lock.unlock() }
        return self.conversationId == conversationId
    }
}
