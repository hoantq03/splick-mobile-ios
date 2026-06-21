import Foundation

/// Tokenizes feed text for mentions (`@username`) and custom emoji shortcodes (`:name:`).
public enum FeedTextParser {
    public enum Token: Equatable, Sendable, Identifiable {
        case plain(String)
        case mention(String)
        case customEmoji(shortcode: String)

        public var id: String {
            switch self {
            case .plain(let value):
                return "plain:\(value)"
            case .mention(let value):
                return "mention:\(value)"
            case .customEmoji(let shortcode):
                return "emoji:\(shortcode)"
            }
        }
    }

    private static let customEmojiPattern = #/:([a-z0-9_]{1,30}):/#

    public static func tokens(in text: String) -> [Token] {
        guard !text.isEmpty else { return [] }

        var result: [Token] = []
        var cursor = text.startIndex

        while cursor < text.endIndex {
            let mentionMatch = text[cursor...].firstMatch(of: MentionStyler.usernamePattern)
            let emojiMatch = text[cursor...].firstMatch(of: customEmojiPattern)

            let nextMention = mentionMatch?.range.lowerBound
            let nextEmoji = emojiMatch?.range.lowerBound

            let nextSpecial = [nextMention, nextEmoji].compactMap { $0 }.min()

            if let nextSpecial {
                if nextSpecial > cursor {
                    appendPlain(String(text[cursor..<nextSpecial]), to: &result)
                }

                if nextMention == nextSpecial, let mentionMatch {
                    result.append(.mention(String(text[mentionMatch.range])))
                    cursor = mentionMatch.range.upperBound
                    continue
                }

                if nextEmoji == nextSpecial, let emojiMatch {
                    let matched = String(text[emojiMatch.range])
                    let shortcode = String(matched.dropFirst().dropLast())
                    result.append(.customEmoji(shortcode: shortcode))
                    cursor = emojiMatch.range.upperBound
                    continue
                }
            }

            appendPlain(String(text[cursor...]), to: &result)
            break
        }

        return result
    }

    private static func appendPlain(_ value: String, to result: inout [Token]) {
        guard !value.isEmpty else { return }
        if case .plain(let existing)? = result.last {
            result[result.count - 1] = .plain(existing + value)
        } else {
            result.append(.plain(value))
        }
    }
}
