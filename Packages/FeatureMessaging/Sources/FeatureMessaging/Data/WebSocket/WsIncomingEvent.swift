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
                body: event.message.body,
                clientMessageId: event.message.clientMessageId ?? UUID(),
                createdAt: event.message.createdAt,
                sequenceNo: event.message.sequenceNo ?? 0,
                deliveryStatus: .sent,
                imageAttachments: imageAttachments
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

        default:
            return nil
        }
    }

    private struct WsEventEnvelope: Decodable {
        let type: String
    }
}
