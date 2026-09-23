import SwiftUI

/// Read-only text with `@username` tokens styled as mentions.
/// Storage stays `@username`; optional map shows display names instead.
public struct MentionText: View {
    let text: String
    var fontSize: CGFloat = 12
    var plainColor: Color = SplickTheme.Colors.textPrimary
    /// Lowercased username → display name. Missing keys fall back to `@username`.
    var displayNamesByUsername: [String: String] = [:]
    var onMentionTap: ((String) -> Void)?
    /// Enables native text selection / copy. Prefer for captions and comments.
    var isSelectable: Bool
    var displayNamesByUserId: [UUID: String] = [:]
    var lineLimit: Int? = nil
    var onTruncationChange: ((Bool) -> Void)? = nil
    var onPlainTap: (() -> Void)? = nil

    public init(
        _ text: String,
        fontSize: CGFloat = 12,
        plainColor: Color = SplickTheme.Colors.textPrimary,
        displayNamesByUsername: [String: String] = [:],
        onMentionTap: ((String) -> Void)? = nil,
        isSelectable: Bool = false,
        displayNamesByUserId: [UUID: String] = [:],
        lineLimit: Int? = nil,
        onTruncationChange: ((Bool) -> Void)? = nil,
        onPlainTap: (() -> Void)? = nil
    ) {
        self.text = text
        self.fontSize = fontSize
        self.plainColor = plainColor
        self.displayNamesByUsername = displayNamesByUsername
        self.onMentionTap = onMentionTap
        self.isSelectable = isSelectable
        self.displayNamesByUserId = displayNamesByUserId
        self.lineLimit = lineLimit
        self.onTruncationChange = onTruncationChange
        self.onPlainTap = onPlainTap
    }

    public var body: some View {
        EmojiResolvingText(
            text,
            fontSize: fontSize,
            plainColor: plainColor,
            displayNamesByUsername: displayNamesByUsername,
            onMentionTap: onMentionTap,
            isSelectable: isSelectable,
            displayNamesByUserId: displayNamesByUserId,
            lineLimit: lineLimit,
            onTruncationChange: onTruncationChange,
            onPlainTap: onPlainTap
        )
    }
}
