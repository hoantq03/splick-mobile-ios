import SwiftUI

/// Read-only text with `@username` in bold blue.
public struct MentionText: View {
    let text: String
    var fontSize: CGFloat = 12
    var plainColor: Color = SplickTheme.Colors.textPrimary

    public init(
        _ text: String,
        fontSize: CGFloat = 12,
        plainColor: Color = SplickTheme.Colors.textPrimary
    ) {
        self.text = text
        self.fontSize = fontSize
        self.plainColor = plainColor
    }

    public var body: some View {
        Group {
            if text.isEmpty {
                Text(verbatim: "")
            } else {
                styledText
            }
        }
    }

    private var styledText: Text {
        MentionStyler.segments(in: text).reduce(Text(verbatim: "")) { partial, segment in
            let piece = segment.isMention
                ? Text(segment.content)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundColor(SplickTheme.Colors.info)
                : Text(segment.content)
                    .font(.system(size: fontSize))
                    .foregroundColor(plainColor)
            return partial + piece
        }
    }
}
