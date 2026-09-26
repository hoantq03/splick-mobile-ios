import Foundation

/// GIF keyword from a composer draft: exactly two whitespace-separated words.
public enum GifKeywordDetector {
    public static let minimumLength = 2
    public static let maximumLength = 40
    public static let requiredWordCount = 2

    public static func keyword(
        in draft: String,
        cursor: Int? = nil,
        mentionActive: Bool = false
    ) -> String? {
        guard !mentionActive else { return nil }

        let end = min(max(0, cursor ?? draft.count), draft.count)
        guard end > 0 else { return nil }
        let prefix = String(draft.prefix(end))
        guard whitespaceWordCount(in: prefix) == requiredWordCount else { return nil }
        guard let token = lastAlphanumericToken(in: prefix) else { return nil }

        let folded = token.lowercased()
        guard folded.count >= minimumLength, folded.count <= maximumLength else { return nil }
        guard !stopwords.contains(folded) else { return nil }
        return token
    }

    private static func whitespaceWordCount(in prefix: String) -> Int {
        prefix.split(whereSeparator: \.isWhitespace).filter { !$0.isEmpty }.count
    }

    private static func lastAlphanumericToken(in prefix: String) -> String? {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let stripped = trimmed.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard !stripped.isEmpty else { return nil }

        var token = ""
        var index = stripped.endIndex
        while index > stripped.startIndex {
            let previous = stripped.index(before: index)
            let character = stripped[previous]
            if character.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) {
                token.insert(character, at: token.startIndex)
                index = previous
            } else {
                break
            }
        }
        guard !token.isEmpty else { return nil }
        if index > stripped.startIndex {
            let before = stripped[stripped.index(before: index)]
            if before == "@" { return nil }
        }
        return token
    }

    private static let stopwords: Set<String> = [
        "a", "an", "the", "is", "are", "was", "were", "am", "be", "to", "of", "in", "on",
        "for", "and", "or", "but", "not", "it", "me", "my", "you", "we", "they", "i",
        "at", "as", "by", "this", "that", "with", "from", "so", "if", "do", "did",
        "just", "ok", "oh", "la", "là", "và", "tôi", "mình", "của", "cho", "các",
        "một", "không", "ko", "có", "được", "thi", "thì", "này", "đó", "để", "voi",
        "với", "như", "đã", "sẽ", "đang", "nhưng", "hay", "hoặc", "vì", "nên",
        "rất", "hơn", "nữa", "ơi", "ạ", "nhé", "nha", "đi", "ra", "vào", "lên",
        "xuống", "rồi", "thôi", "ạ", "uh", "ừ",
    ]
}
