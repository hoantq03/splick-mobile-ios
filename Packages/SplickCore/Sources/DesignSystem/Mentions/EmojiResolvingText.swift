import SwiftUI
import UIKit

/// Read-only inline text that styles `@mentions` and renders `:custom_emoji:` shortcodes as images.
public struct EmojiResolvingText: View {
    private let text: String
    private let fontSize: CGFloat
    private let plainColor: Color
    private let displayNamesByUsername: [String: String]
    private let onMentionTap: ((String) -> Void)?
    private let isSelectable: Bool

    public init(
        _ text: String,
        fontSize: CGFloat = 12,
        plainColor: Color = SplickTheme.Colors.textPrimary,
        displayNamesByUsername: [String: String] = [:],
        onMentionTap: ((String) -> Void)? = nil,
        isSelectable: Bool = false
    ) {
        self.text = text
        self.fontSize = fontSize
        self.plainColor = plainColor
        self.displayNamesByUsername = displayNamesByUsername
        self.onMentionTap = onMentionTap
        self.isSelectable = isSelectable
    }

    private var tokens: [FeedTextParser.Token] {
        FeedTextParser.tokens(in: text)
    }

    private var hasCustomEmoji: Bool {
        tokens.contains { token in
            if case .customEmoji = token { return true }
            return false
        }
    }

    public var body: some View {
        Group {
            if text.isEmpty {
                Text(verbatim: "")
            } else if isSelectable, !hasCustomEmoji {
                SelectableMentionTextView(
                    text: text,
                    fontSize: fontSize,
                    plainColor: plainColor,
                    displayNamesByUsername: displayNamesByUsername,
                    onMentionTap: onMentionTap
                )
                .fixedSize(horizontal: false, vertical: true)
            } else {
                tokenFlow
            }
        }
    }

    private var tokenFlow: some View {
        FlowLayout(spacing: 1, lineSpacing: 2) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                tokenView(token)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            if isSelectable {
                Button {
                    UIPasteboard.general.string = SelectableMentionTextView.displayString(
                        text: text,
                        displayNamesByUsername: displayNamesByUsername
                    )
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
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
            let username = MentionStyler.username(fromMentionToken: value)
            let label = mentionLabel(for: value)
            if let onMentionTap {
                Button {
                    onMentionTap(username)
                } label: {
                    Text(label)
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundStyle(SplickTheme.Colors.info)
                }
                .buttonStyle(.plain)
            } else {
                Text(label)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.info)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .customEmoji(let shortcode):
            EmojiView(value: ":\(shortcode):", size: fontSize * 1.2)
        }
    }

    /// `value` is the raw token including `@` (e.g. `@hoantran`).
    private func mentionLabel(for value: String) -> String {
        let username = value.hasPrefix("@") ? String(value.dropFirst()) : value
        let key = username.lowercased()
        if let displayName = displayNamesByUsername[key], !displayName.isEmpty {
            return "@\(displayName)"
        }
        return value
    }
}
