import SwiftUI

/// Read-only text with `@username` tokens styled as mentions.
/// Storage stays `@username`; optional map shows display names instead.
public struct MentionText: View {
    let text: String
    var fontSize: CGFloat = 12
    var plainColor: Color = SplickTheme.Colors.textPrimary
    /// Lowercased username → display name. Missing keys fall back to `@username`.
    var displayNamesByUsername: [String: String] = [:]

    public init(
        _ text: String,
        fontSize: CGFloat = 12,
        plainColor: Color = SplickTheme.Colors.textPrimary,
        displayNamesByUsername: [String: String] = [:]
    ) {
        self.text = text
        self.fontSize = fontSize
        self.plainColor = plainColor
        self.displayNamesByUsername = displayNamesByUsername
    }

    public var body: some View {
        EmojiResolvingText(
            text,
            fontSize: fontSize,
            plainColor: plainColor,
            displayNamesByUsername: displayNamesByUsername
        )
    }
}
