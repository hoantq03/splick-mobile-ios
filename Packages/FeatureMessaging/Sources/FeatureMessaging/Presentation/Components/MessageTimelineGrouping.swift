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
    /// Centered Facebook-style summary above this row (new cluster).
    let showsTimeSeparator: Bool
    let imageAttachments: [MessageImageAttachment]

    var id: UUID { message.clientMessageId }
}

enum MessageTimelineGrouping {
    /// Same-sender bubbles stack tightly within this window.
    static let groupWindow: TimeInterval = 5 * 60
    /// A new time-summary cluster starts after this idle gap (or a calendar-day change).
    static let timeSeparatorWindow: TimeInterval = 30 * 60

    static func buildDisplayMessages(
        from messages: [ChatMessage],
        calendar: Calendar = .current
    ) -> [DisplayMessage] {
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
                showsTimeSeparator: shouldShowTimeSeparator(
                    previous: previous,
                    current: message,
                    calendar: calendar
                ),
                imageAttachments: message.imageAttachments
            )
        }
    }

    static func isSameGroup(_ earlier: ChatMessage, _ later: ChatMessage) -> Bool {
        guard !earlier.isSystemNotice, !later.isSystemNotice else { return false }
        return earlier.senderId == later.senderId
            && later.createdAt.timeIntervalSince(earlier.createdAt) <= groupWindow
    }

    static func shouldShowTimeSeparator(
        previous: ChatMessage?,
        current: ChatMessage,
        calendar: Calendar = .current
    ) -> Bool {
        guard let previous else { return true }
        if !calendar.isDate(previous.createdAt, inSameDayAs: current.createdAt) {
            return true
        }
        return current.createdAt.timeIntervalSince(previous.createdAt) >= timeSeparatorWindow
    }
}
