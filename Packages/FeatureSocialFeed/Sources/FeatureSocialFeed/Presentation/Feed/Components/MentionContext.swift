import Foundation

/// Active `@mention` being typed at the end of the comment draft.
struct MentionContext: Equatable {
    let query: String
    let replaceRange: Range<String.Index>

    static func active(in text: String) -> MentionContext? {
        guard let atRange = text.range(of: "@", options: .backwards) else { return nil }

        if atRange.lowerBound > text.startIndex {
            let before = text[text.index(before: atRange.lowerBound)]
            if !before.isWhitespace && before != "\n" {
                return nil
            }
        }

        let queryStart = atRange.upperBound
        let queryPart = text[queryStart...]
        if queryPart.contains(where: \.isWhitespace) {
            return nil
        }

        return MentionContext(
            query: String(queryPart),
            replaceRange: atRange.lowerBound..<text.endIndex
        )
    }
}
