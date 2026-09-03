import SwiftUI
import UIKit

/// Parses and styles mention tokens. Durable mentions are `<@uuid>`; legacy `@username` is still parsed.
public enum MentionStyler {
    /// Extended literal so leading `@` is not parsed as a Swift attribute.
    public static let usernamePattern = #/@([A-Za-z0-9_]{2,30}(?:\.[A-Za-z0-9_]+)*)/#
    public static let userIdPattern =
        #/<@([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})>/#

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

        for range in mentionRanges(in: text) {
            if range.lowerBound > searchStart {
                result.append(Segment(
                    content: String(text[searchStart..<range.lowerBound]),
                    isMention: false
                ))
            }
            result.append(Segment(
                content: String(text[range]),
                isMention: true
            ))
            searchStart = range.upperBound
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

    public static func mentionRanges(in text: String) -> [Range<String.Index>] {
        let idRanges = text.matches(of: userIdPattern).map(\.range)
        let usernameRanges = text.matches(of: usernamePattern).map(\.range).filter { usernameRange in
            !idRanges.contains { $0.overlaps(usernameRange) }
        }
        return (idRanges + usernameRanges).sorted { $0.lowerBound < $1.lowerBound }
    }

    public static func username(fromMentionToken token: String) -> String {
        if let userId = userId(fromMentionToken: token) {
            return userId.uuidString.lowercased()
        }
        return token.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
    }

    public static func userId(fromMentionToken token: String) -> UUID? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("<@"), trimmed.hasSuffix(">") else { return nil }
        return UUID(uuidString: String(trimmed.dropFirst(2).dropLast()))
    }

    public static func mentionLabel(
        token: String,
        displayNamesByUsername: [String: String] = [:],
        displayNamesByUserId: [UUID: String] = [:]
    ) -> String {
        if let userId = userId(fromMentionToken: token) {
            if let displayName = displayNamesByUserId[userId], !displayName.isEmpty {
                return "@\(displayName)"
            }
            let key = userId.uuidString.lowercased()
            if let displayName = displayNamesByUsername[key], !displayName.isEmpty {
                return "@\(displayName)"
            }
            return token
        }
        let username = username(fromMentionToken: token)
        let key = username.lowercased()
        if let displayName = displayNamesByUsername[key], !displayName.isEmpty {
            return "@\(displayName)"
        }
        return token.hasPrefix("@") ? token : "@\(username)"
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
            let displayed = segment.isMention
                ? mentionLabel(token: segment.content)
                : segment.content
            result.append(NSAttributedString(string: displayed, attributes: attributes))
        }

        return result
    }
}
