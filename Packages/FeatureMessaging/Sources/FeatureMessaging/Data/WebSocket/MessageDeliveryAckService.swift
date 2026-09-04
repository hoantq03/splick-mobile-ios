import Foundation

/// Shared entry point for acknowledging that a message reached this device.
@MainActor
public final class MessageDeliveryAckService {
    public static let shared = MessageDeliveryAckService()

    private weak var wsClient: MessagingWebSocketClient?
    private var recentAcks: [String: Date] = [:]
    private let ackDedupWindow: TimeInterval = 30

    private init() {}

    public func configure(wsClient: MessagingWebSocketClient) {
        self.wsClient = wsClient
    }

    /// Sends `message.delivered` when this device has received the message (WS or push).
    public func acknowledge(conversationId: UUID, messageId: UUID) {
        let key = "\(conversationId.uuidString):\(messageId.uuidString)"
        let now = Date()
        if let last = recentAcks[key], now.timeIntervalSince(last) < ackDedupWindow {
            return
        }
        recentAcks[key] = now
        pruneStaleAcks(now: now)
        lastAcknowledgedConversationId = conversationId
        lastAcknowledgedMessageId = messageId
        wsClient?.sendDeliveryAck(conversationId: conversationId, messageId: messageId)
    }

    /// Test/observation hook for the most recent ACK.
    public private(set) var lastAcknowledgedConversationId: UUID?
    public private(set) var lastAcknowledgedMessageId: UUID?

    public func resetAckTrackingForTests() {
        recentAcks.removeAll()
        lastAcknowledgedConversationId = nil
        lastAcknowledgedMessageId = nil
    }

    private func pruneStaleAcks(now: Date) {
        recentAcks = recentAcks.filter { now.timeIntervalSince($0.value) < ackDedupWindow * 2 }
    }
}
