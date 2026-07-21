import Foundation
import SplickDomain

enum ConversationPreviewContent: Equatable {
    case text(String)
    case emoji
    case images(Int)
}

enum ConversationPreviewFormatter {
    static func content(for message: ChatMessage) -> ConversationPreviewContent {
        if !message.imageAttachments.isEmpty {
            return .images(message.imageAttachments.count)
        }

        let body = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if isEmojiOnly(body) {
            return .emoji
        }
        return .text(body)
    }

    static func senderLabel(
        for message: ChatMessage,
        currentUserId: UUID?,
        meLabel: String,
        fallbackDisplayName: String?,
        unknownLabel: String
    ) -> String {
        if message.senderId == currentUserId {
            return meLabel
        }

        return shortName(from: message.senderDisplayName)
            ?? shortName(from: fallbackDisplayName)
            ?? unknownLabel
    }

    private static func shortName(from displayName: String?) -> String? {
        guard let displayName else { return nil }
        let components = displayName.split(whereSeparator: \.isWhitespace)
        return components.last.map(String.init)
    }

    private static func isEmojiOnly(_ text: String) -> Bool {
        let characters = text.filter { !$0.isWhitespace }
        return !characters.isEmpty && characters.allSatisfy(\.isPreviewEmoji)
    }
}

private extension Character {
    var isPreviewEmoji: Bool {
        let scalars = unicodeScalars
        return scalars.contains { scalar in
            scalar.properties.isEmojiPresentation
                || (scalar.properties.isEmoji && scalar.value > 0x238C)
        } || (scalars.count > 1 && scalars.contains { $0.properties.isEmoji })
    }
}
