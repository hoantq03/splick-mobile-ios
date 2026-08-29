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

    public static func username(from url: URL) -> String? {
        guard url.scheme == scheme else { return nil }
        let value = url.path.split(separator: "/").last.map(String.init)
        return value?.removingPercentEncoding
    }
}
