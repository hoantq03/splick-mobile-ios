import Foundation

enum CustomEmojiShortcodeValidator {
    private static let pattern = try! NSRegularExpression(pattern: "^[a-z0-9_]{1,30}$")

    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix(":"), value.hasSuffix(":"), value.count > 2 {
            value = String(value.dropFirst().dropLast())
        }
        return value
    }

    static func isValid(_ raw: String) -> Bool {
        let value = normalize(raw)
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return pattern.firstMatch(in: value, range: range) != nil
    }
}
