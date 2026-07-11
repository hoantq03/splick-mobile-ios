import Foundation
import SplickDomain

enum MessageGroupPosition: Equatable {
    case standalone
    case groupFirst
    case groupMiddle
    case groupLast
}

struct DisplayMessage: Identifiable, Equatable {
    let message: ChatMessage
    let groupPosition: MessageGroupPosition
    let showsTimestamp: Bool
    let imageAttachments: [MessageImageAttachment]

    var id: UUID { message.id }
}

enum MessageTimelineGrouping {
    static let groupWindow: TimeInterval = 5 * 60

    static func buildDisplayMessages(from messages: [ChatMessage]) -> [DisplayMessage] {
        guard !messages.isEmpty else { return [] }

        return messages.enumerated().map { index, message in
            let previous = index > 0 ? messages[index - 1] : nil
            let next = index < messages.count - 1 ? messages[index + 1] : nil

            let groupsWithPrevious = previous.map { isSameGroup($0, message) } ?? false
            let groupsWithNext = next.map { isSameGroup(message, $0) } ?? false

            let position: MessageGroupPosition
            switch (groupsWithPrevious, groupsWithNext) {
            case (false, false):
                position = .standalone
            case (false, true):
                position = .groupFirst
            case (true, true):
                position = .groupMiddle
            case (true, false):
                position = .groupLast
            }

            return DisplayMessage(
                message: message,
                groupPosition: position,
                showsTimestamp: !groupsWithNext,
                imageAttachments: message.imageAttachments
            )
        }
    }

    static func isSameGroup(_ earlier: ChatMessage, _ later: ChatMessage) -> Bool {
        earlier.senderId == later.senderId
            && later.createdAt.timeIntervalSince(earlier.createdAt) <= groupWindow
    }
}
