import Foundation
import SplickDomain

struct WsNewMessageEvent: Decodable {
    let conversationId: UUID
    let message: MessagePayload

    struct MessagePayload: Decodable {
        let id: UUID
        let senderId: UUID
        let body: String
        let createdAt: String
    }
}

struct WsReadReceiptEvent: Decodable {
    let conversationId: UUID
    let readerId: UUID
    let upToMessageId: UUID
}

struct WsDeliveryAckEvent: Decodable {
    let conversationId: UUID
    let messageId: UUID
}
