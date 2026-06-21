import SwiftUI

/// Read-only inline text that styles `@mentions` and renders `:custom_emoji:` shortcodes as images.
public struct EmojiResolvingText: View {
    private let text: String
    private let fontSize: CGFloat
    private let plainColor: Color

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
                FlowLayout(spacing: 1, lineSpacing: 2) {
                    ForEach(Array(FeedTextParser.tokens(in: text).enumerated()), id: \.offset) { _, token in
                        tokenView(token)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func tokenView(_ token: FeedTextParser.Token) -> some View {
        switch token {
        case .plain(let value):
            Text(value)
                .font(.system(size: fontSize))
                .foregroundStyle(plainColor)
                .fixedSize(horizontal: false, vertical: true)

        case .mention(let value):
            Text(value)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.info)
                .fixedSize(horizontal: false, vertical: true)

        case .customEmoji(let shortcode):
            EmojiView(value: ":\(shortcode):", size: fontSize * 1.2)
        }
    }
}
