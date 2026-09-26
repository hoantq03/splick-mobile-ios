import Foundation

public enum EmojiKind: Equatable, Sendable {
    case unicode(String)
    case custom(shortcode: String)

    public static func from(_ value: String) -> EmojiKind {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3,
              trimmed.hasPrefix(":"),
              trimmed.hasSuffix(":"),
              !trimmed.dropFirst().dropLast().contains(":")
        else {
            return .unicode(trimmed)
        }
        let shortcode = String(trimmed.dropFirst().dropLast())
        guard !shortcode.isEmpty else { return .unicode(trimmed) }
        return .custom(shortcode: shortcode)
    }

    public var storageValue: String {
        switch self {
        case .unicode(let value):
            return value
        case .custom(let shortcode):
            return ":\(shortcode):"
        }
    }
}
