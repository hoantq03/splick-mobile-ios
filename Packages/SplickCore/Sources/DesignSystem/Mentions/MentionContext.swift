import Foundation

/// Active `@mention` being typed at the end of a draft.
public struct MentionContext: Equatable, Sendable {
    public let query: String
    public let replaceRange: Range<String.Index>

    public static func active(in text: String) -> MentionContext? {
        guard let atRange = text.range(of: "@", options: .backwards) else { return nil }

        let afterAt = text[atRange.upperBound...]
        if afterAt.contains(where: { $0.isWhitespace || $0.isNewline }) {
            return nil
        }

        let query = String(afterAt)
        guard query.count <= 30 else { return nil }
        guard query.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }) else { return nil }

        return MentionContext(query: query, replaceRange: atRange.lowerBound..<text.endIndex)
    }

    public static func token(for userId: UUID) -> String {
        "<@\(userId.uuidString)>"
    }

    public static func insertMention(userId: UUID, in text: inout String) -> Bool {
        guard let context = active(in: text) else { return false }
        text.replaceSubrange(context.replaceRange, with: "\(token(for: userId)) ")
        return true
    }
}
