import Foundation
import SplickDomain

public struct PendingOutboundMessage: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID { clientMessageId }

    public let conversationId: UUID
    public let clientMessageId: UUID
    public let body: String
    public let imageAttachments: [MessageImageAttachment]
    public let replyToMessageId: UUID?
    public let createdAt: Date
    public let status: MessageDeliveryStatus

    public init(
        conversationId: UUID,
        clientMessageId: UUID,
        body: String,
        imageAttachments: [MessageImageAttachment] = [],
        replyToMessageId: UUID? = nil,
        createdAt: Date = .now,
        status: MessageDeliveryStatus = .failed
    ) {
        self.conversationId = conversationId
        self.clientMessageId = clientMessageId
        self.body = body
        self.imageAttachments = imageAttachments
        self.replyToMessageId = replyToMessageId
        self.createdAt = createdAt
        self.status = status
    }
}

/// File-backed queue of outbound messages that failed to send.
public final class PendingMessageStore: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
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

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let directory = support.appendingPathComponent("Splick", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.fileURL = directory.appendingPathComponent("pending-messages.json")
        }
    }

    public func save(_ message: PendingOutboundMessage) {
        lock.lock()
        defer { lock.unlock() }
        var items = loadUnlocked()
        items.removeAll { $0.clientMessageId == message.clientMessageId }
        items.append(message)
        persistUnlocked(items)
    }

    public func remove(clientMessageId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        var items = loadUnlocked()
        items.removeAll { $0.clientMessageId == clientMessageId }
        persistUnlocked(items)
    }

    public func all() -> [PendingOutboundMessage] {
        lock.lock()
        defer { lock.unlock() }
        return loadUnlocked()
    }

    public func all(for conversationId: UUID) -> [PendingOutboundMessage] {
        all().filter { $0.conversationId == conversationId }
    }

    private func loadUnlocked() -> [PendingOutboundMessage] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([PendingOutboundMessage].self, from: data)) ?? []
    }

    private func persistUnlocked(_ items: [PendingOutboundMessage]) {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
