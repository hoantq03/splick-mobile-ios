import Foundation

/// Shared posts are sent as plain chat text: optional note + `https://splick.app/post/{uuid}`.
public struct PostSharePayload: Equatable, Sendable {
    public let postId: UUID
    /// Non-URL portion of the message body (trimmed). `nil` when the body is URL-only.
    public let note: String?
    public let shareURL: String

    public init(postId: UUID, note: String?, shareURL: String) {
        self.postId = postId
        self.note = note
        self.shareURL = shareURL
    }
}

public enum PostShareUrlParser {
    private static let httpsPattern =
        #"(?i)https?://(?:www\.)?splick\.app/post/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/?"#
    private static let schemePattern =
        #"(?i)splick://post/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/?"#

    public static func parse(_ body: String) -> PostSharePayload? {
        guard let match = firstMatch(in: body, pattern: httpsPattern)
            ?? firstMatch(in: body, pattern: schemePattern),
            let postId = UUID(uuidString: match.uuidString)
        else {
            return nil
        }
        let shareURL = match.matchedString.trimmingCharacters(in: CharacterSet(charactersIn: "/?#"))
        var note = body
        if let range = Range(match.nsRange, in: body) {
            note.removeSubrange(range)
        }
        note = note
            .replacingOccurrences(of: #"\n{2,}"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return PostSharePayload(
            postId: postId,
            note: note.isEmpty ? nil : note,
            shareURL: shareURL
        )
    }

    public static func extractPostId(from urlString: String) -> UUID? {
        parse(urlString)?.postId
    }

    private struct RegexMatch {
        let matchedString: String
        let uuidString: String
        let nsRange: NSRange
    }

    private static func firstMatch(in body: String, pattern: String) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsBody = body as NSString
        let fullRange = NSRange(location: 0, length: nsBody.length)
        guard let match = regex.firstMatch(in: body, options: [], range: fullRange),
              match.numberOfRanges >= 2
        else {
            return nil
        }
        let uuidRange = match.range(at: 1)
        guard uuidRange.location != NSNotFound else { return nil }
        return RegexMatch(
            matchedString: nsBody.substring(with: match.range),
            uuidString: nsBody.substring(with: uuidRange),
            nsRange: match.range
        )
    }
}
