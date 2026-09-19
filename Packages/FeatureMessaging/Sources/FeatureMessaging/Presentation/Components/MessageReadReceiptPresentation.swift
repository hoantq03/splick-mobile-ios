import Foundation
import SplickDomain

enum MessageReadReceiptPresentation {
    /// Avatar is shown only on the newest outgoing message that is `.read`.
    static func latestReadOutgoingMessageId(
        in messages: [ChatMessage],
        currentUserId: UUID
    ) -> UUID? {
        messages.last(where: {
            $0.senderId == currentUserId && $0.deliveryStatus == .read
        })?.id
    }

    /// Marks the current user's outgoing messages as `.read` up to the peer cursor.
    /// Ignores receipts from the current user so local mark-read does not look like the peer saw the thread.
    static func applyingReadReceipt(
        to messages: [ChatMessage],
        currentUserId: UUID,
        readerId: UUID,
        upToMessageId: UUID,
        upToSequence: Int64?
    ) -> [ChatMessage]? {
        guard readerId != currentUserId else { return nil }

        let anchor = messages.first(where: { $0.id == upToMessageId })
        let capSequence = (upToSequence ?? 0) > 0 ? (upToSequence ?? 0) : (anchor?.sequenceNo ?? 0)
        let capDate = anchor?.createdAt

        var next = messages
        var changed = false
        for index in next.indices {
            let message = next[index]
            guard message.senderId == currentUserId,
                  message.deliveryStatus != .read,
                  message.deliveryStatus != .failed else { continue }
            guard coversCursor(
                message: message,
                capSequence: capSequence,
                capDate: capDate
            ) else { continue }
            next[index] = message.updating(deliveryStatus: .read)
            changed = true
        }
        return changed ? next : nil
    }

    static func applyingDeliveryAck(
        to messages: [ChatMessage],
        currentUserId: UUID,
        messageId: UUID
    ) -> [ChatMessage]? {
        guard let ackMessage = messages.first(where: { $0.id == messageId }) else { return nil }
        let ackSequence = ackMessage.sequenceNo
        let ackCreatedAt = ackMessage.createdAt

        var next = messages
        var changed = false
        for index in next.indices {
            let message = next[index]
            guard message.senderId == currentUserId,
                  message.deliveryStatus == .sent || message.deliveryStatus == .sending
            else { continue }
            let covers: Bool
            if ackSequence > 0, message.sequenceNo > 0 {
                covers = message.sequenceNo <= ackSequence
            } else {
                covers = message.createdAt <= ackCreatedAt
            }
            guard covers else { continue }
            next[index] = message.updating(deliveryStatus: .delivered)
            changed = true
        }
        return changed ? next : nil
    }

    private static func coversCursor(
        message: ChatMessage,
        capSequence: Int64,
        capDate: Date?
    ) -> Bool {
        if capSequence > 0, message.sequenceNo > 0 {
            return message.sequenceNo <= capSequence
        }
        if let capDate {
            return message.createdAt <= capDate
        }
        return false
    }
}
