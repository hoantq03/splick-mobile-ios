import Foundation
import SwiftUI
import DesignSystem

enum MessageBodyLinkifier {
    private static let cache = NSCache<NSString, CachedAttributedString>()
    private static let cacheLimit = 256

    private final class CachedAttributedString: NSObject {
        let value: AttributedString
        init(_ value: AttributedString) {
            self.value = value
        }
    }

    static func attributed(_ body: String, isOutgoing: Bool) -> AttributedString {
        // `nolink|` — do not attach `.link` (UITextItemInteraction pans steal reply on iOS 17).
        let cacheKey = "nolink|\(isOutgoing ? "out" : "in")|\(body)" as NSString
        if cache.countLimit != cacheLimit {
            cache.countLimit = cacheLimit
        }
        if let cached = cache.object(forKey: cacheKey) {
            return cached.value
        }

        let textColor: Color = isOutgoing ? .white : SplickTheme.Colors.textPrimary
        let linkColor: Color = isOutgoing ? .white : SplickTheme.Colors.primaryGradientStart

        var attributed = AttributedString(body)
        attributed.foregroundColor = textColor

        // Style URL ranges visually only — never set `.link` (that installs text pans).
        if looksLikeItMayContainURL(body),
           let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let nsBody = body as NSString
            let matches = detector.matches(
                in: body,
                options: [],
                range: NSRange(location: 0, length: nsBody.length)
            )
            for match in matches {
                guard
                    match.url != nil,
                    let stringRange = Range(match.range, in: body),
                    let attributedRange = Range(stringRange, in: attributed)
                else { continue }
                attributed[attributedRange].foregroundColor = linkColor
                attributed[attributedRange].underlineStyle = .single
            }
        }

        cache.setObject(CachedAttributedString(attributed), forKey: cacheKey)
        return attributed
    }

    /// URLs detected in a message body (for tap-to-open when Text hit-testing is disabled).
    static func urls(in body: String) -> [URL] {
        guard looksLikeItMayContainURL(body),
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return [] }
        let nsBody = body as NSString
        return detector.matches(
            in: body,
            options: [],
            range: NSRange(location: 0, length: nsBody.length)
        ).compactMap(\.url)
    }

    private static func looksLikeItMayContainURL(_ body: String) -> Bool {
        body.contains("://")
            || body.contains("www.")
            || body.contains(".")
            || body.contains("@")
    }
}
