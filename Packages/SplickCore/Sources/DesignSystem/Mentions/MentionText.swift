import SwiftUI

/// Read-only text with `@username` in bold blue and optional `:custom_emoji:` images.
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
        EmojiResolvingText(text, fontSize: fontSize, plainColor: plainColor)
    }
}
