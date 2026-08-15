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
}
