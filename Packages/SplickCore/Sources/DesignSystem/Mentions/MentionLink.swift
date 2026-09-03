import Foundation

/// Deep-link used inside selectable caption/comment `UITextView`s so mention taps
/// can be distinguished from text selection.
public enum MentionLink {
    public static let scheme = "splick-mention"

    public static func url(username: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "u"
        components.path = "/" + username
        return components.url
    }

    public static func url(userId: UUID) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "id"
        components.path = "/" + userId.uuidString.lowercased()
        return components.url
    }

    public static func url(token: String) -> URL? {
        if let userId = MentionStyler.userId(fromMentionToken: token) {
            return url(userId: userId)
        }
        return url(username: MentionStyler.username(fromMentionToken: token))
    }

    /// Username or lowercase userId string used to resolve the tagged person.
    public static func username(from url: URL) -> String? {
        guard url.scheme == scheme else { return nil }
        let value = url.path.split(separator: "/").last.map(String.init)
        return value?.removingPercentEncoding
    }
}
