import Foundation
import SwiftUI

enum MessageBodyLinkifier {
    static func attributed(_ body: String, textColor: Color, linkColor: Color) -> AttributedString {
        var attributed = AttributedString(body)
        attributed.foregroundColor = textColor
        guard
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else {
            return attributed
        }
        let nsBody = body as NSString
        let matches = detector.matches(in: body, options: [], range: NSRange(location: 0, length: nsBody.length))
        for match in matches {
            guard
                let url = match.url,
                let stringRange = Range(match.range, in: body),
                let attributedRange = Range(stringRange, in: attributed)
            else { continue }
            attributed[attributedRange].link = url
            attributed[attributedRange].foregroundColor = linkColor
            attributed[attributedRange].underlineStyle = .single
        }
        return attributed
    }
}
