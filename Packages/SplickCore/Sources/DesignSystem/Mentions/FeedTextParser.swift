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
            let remaining = text[cursor...]
            let idMatch = remaining.firstMatch(of: MentionStyler.userIdPattern)
            let mentionMatch = remaining.firstMatch(of: MentionStyler.usernamePattern)
            let emojiMatch = remaining.firstMatch(of: customEmojiPattern)

            let nextId = idMatch?.range.lowerBound
            let nextMention: String.Index?
            if let mentionMatch {
                if let idRange = idMatch?.range, mentionMatch.range.overlaps(idRange) {
                    nextMention = nil
                } else {
                    nextMention = mentionMatch.range.lowerBound
                }
            } else {
                nextMention = nil
            }
            let nextEmoji = emojiMatch?.range.lowerBound

            let nextSpecial = [nextId, nextMention, nextEmoji].compactMap { $0 }.min()

            if let nextSpecial {
                if nextSpecial > cursor {
                    appendPlain(String(text[cursor..<nextSpecial]), to: &result)
                }

                if nextId == nextSpecial, let idMatch {
                    result.append(.mention(String(text[idMatch.range])))
                    cursor = idMatch.range.upperBound
                    continue
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
