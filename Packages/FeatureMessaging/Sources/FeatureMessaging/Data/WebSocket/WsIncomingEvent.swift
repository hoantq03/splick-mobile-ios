import Foundation
import Networking
import SplickDomain

struct WsNewMessageEvent: Decodable {
    let conversationId: UUID
    let message: MessagePayload

    struct MessagePayload: Decodable {
        let id: UUID
        let senderId: UUID
        let body: String
        let createdAt: Date
        let sequenceNo: Int64?
        let clientMessageId: UUID?
        let attachments: [MessageAttachmentPayload]?
        let type: String?
        let senderDisplayName: String?
    }

    struct MessageAttachmentPayload: Decodable {
        let mediaId: UUID?
        let url: String
        let thumbnailUrl: String?
    }
}

struct WsReadReceiptEvent: Decodable {
    let conversationId: UUID
    let readerId: UUID
    let upToMessageId: UUID
    let upToSequence: Int64?
}

struct WsDeliveryAckEvent: Decodable {
    let conversationId: UUID
    let messageId: UUID
}

struct WsTypingEvent: Decodable {
    let conversationId: UUID
    let userId: UUID
    let typing: Bool
}

struct WsMessageEditedEvent: Decodable {
    let conversationId: UUID
    let messageId: UUID
    let senderId: UUID
    let body: String
    let editedAt: Date?
}

struct WsMessageRecalledEvent: Decodable {
    let conversationId: UUID
    let messageId: UUID
    let senderId: UUID
}

struct WsPresenceEvent: Decodable {
    let userId: UUID
    let online: Bool
    let lastSeenAt: Date?

    private enum CodingKeys: String, CodingKey {
        case userId
        case online
        case isOnline
        case lastSeenAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        online = try container.decodeIfPresent(Bool.self, forKey: .online)
            ?? container.decodeIfPresent(Bool.self, forKey: .isOnline)
            ?? false
        if let instant = try container.decodeIfPresent(String.self, forKey: .lastSeenAt) {
            lastSeenAt = Self.parseInstant(instant)
        } else {
            lastSeenAt = try? container.decode(Date.self, forKey: .lastSeenAt)
        }
    }

    private static func parseInstant(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        if let date = ISO8601DateFormatter().date(from: raw) { return date }
        if raw.count > 24 {
            let trimmed = String(raw.prefix(23)) + "Z"
            return fractional.date(from: trimmed)
        }
        return nil
    }
}

/// Pure decoding helpers — unit-testable without a live WebSocket.
enum MessagingWsEventDecoder {
    static func decode(_ data: Data, using decoder: JSONDecoder = .apiDecoder) -> MessagingWsEvent? {
        guard let envelope = try? JSONDecoder().decode(WsEventEnvelope.self, from: data) else {
            return nil
        }

        switch envelope.type {
        case "message.new":
            guard let event = try? decoder.decode(WsNewMessageEvent.self, from: data) else { return nil }
            let imageAttachments = (event.message.attachments ?? []).compactMap { attachment -> MessageImageAttachment? in
                guard let url = URL(string: attachment.url) else { return nil }
                return MessageImageAttachment(
                    mediaId: attachment.mediaId,
                    url: url,
                    thumbnailURL: attachment.thumbnailUrl.flatMap(URL.init(string:))
                )
            }
            let msg = ChatMessage(
                id: event.message.id,
                conversationId: event.conversationId,
                senderId: event.message.senderId,
                senderDisplayName: event.message.senderDisplayName,
                body: event.message.body,
                clientMessageId: event.message.clientMessageId ?? UUID(),
                createdAt: event.message.createdAt,
                sequenceNo: event.message.sequenceNo ?? 0,
                deliveryStatus: .sent,
                imageAttachments: imageAttachments,
                type: ChatMessageType(rawValue: event.message.type ?? "") ?? .user
            )
            return .newMessage(conversationId: event.conversationId, message: msg)

        case "message.read":
            guard let event = try? decoder.decode(WsReadReceiptEvent.self, from: data) else { return nil }
            return .readReceipt(
                conversationId: event.conversationId,
                readerId: event.readerId,
                upToMessageId: event.upToMessageId,
                upToSequence: event.upToSequence
            )

        case "message.delivered":
            guard let event = try? decoder.decode(WsDeliveryAckEvent.self, from: data) else { return nil }
            return .deliveryAck(
                conversationId: event.conversationId,
                messageId: event.messageId
            )

        case "typing":
            guard let event = try? decoder.decode(WsTypingEvent.self, from: data) else { return nil }
            return .typing(
                conversationId: event.conversationId,
                userId: event.userId,
                isTyping: event.typing
            )

        case "message.edited":
            guard let event = try? decoder.decode(WsMessageEditedEvent.self, from: data) else { return nil }
            return .messageEdited(
                conversationId: event.conversationId,
                messageId: event.messageId,
                senderId: event.senderId,
                body: event.body
            )

        case "message.recalled":
            guard let event = try? decoder.decode(WsMessageRecalledEvent.self, from: data) else { return nil }
            return .messageRecalled(
                conversationId: event.conversationId,
                messageId: event.messageId,
                senderId: event.senderId
            )

        case "presence":
            guard let event = try? decoder.decode(WsPresenceEvent.self, from: data) else { return nil }
            return .presence(
                userId: event.userId,
                isOnline: event.online,
                lastSeenAt: event.lastSeenAt
            )

        default:
            return nil
        }
    }

    private struct WsEventEnvelope: Decodable {
        let type: String
    }
}
