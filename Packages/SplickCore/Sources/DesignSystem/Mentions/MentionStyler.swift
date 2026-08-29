import SwiftUI
import UIKit

/// Parses and styles `@username` tokens (aligned with backend `FeedMentionParser`).
public enum MentionStyler {
    /// Extended literal so leading `@` is not parsed as a Swift attribute.
    public static let usernamePattern = #/@([a-zA-Z0-9_]{2,30})/#

    public struct Segment: Equatable, Sendable {
        public let content: String
        public let isMention: Bool

        public init(content: String, isMention: Bool) {
            self.content = content
            self.isMention = isMention
        }
    }

    public static func segments(in text: String) -> [Segment] {
        var result: [Segment] = []
        var searchStart = text.startIndex

        for match in text.matches(of: usernamePattern) {
            if match.range.lowerBound > searchStart {
                result.append(Segment(
                    content: String(text[searchStart..<match.range.lowerBound]),
                    isMention: false
                ))
            }
            result.append(Segment(
                content: String(text[match.range]),
                isMention: true
            ))
            searchStart = match.range.upperBound
        }

        if searchStart < text.endIndex {
            result.append(Segment(
                content: String(text[searchStart..<text.endIndex]),
                isMention: false
            ))
        }

        if result.isEmpty {
            result.append(Segment(content: text, isMention: false))
        }

        return result
    }

    public static func username(fromMentionToken token: String) -> String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
    }

    public static func attributedString(
        text: String,
        fontSize: CGFloat,
        plainColor: UIColor = .label,
        mentionColor: UIColor = UIColor(SplickTheme.Colors.info)
    ) -> NSAttributedString {
        let segments = segments(in: text)
        let result = NSMutableAttributedString()
        let plainFont = UIFont.systemFont(ofSize: fontSize)
        let mentionFont = UIFont.systemFont(ofSize: fontSize, weight: .semibold)

        for segment in segments {
            let attributes: [NSAttributedString.Key: Any] = segment.isMention
                ? [.font: mentionFont, .foregroundColor: mentionColor]
                : [.font: plainFont, .foregroundColor: plainColor]
            result.append(NSAttributedString(string: segment.content, attributes: attributes))
        }

        return result
    }
}
