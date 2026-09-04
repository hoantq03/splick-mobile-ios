import SwiftUI
import UIKit

/// Non-scrolling selectable text so captions can be copied and mention links tapped.
struct SelectableMentionTextView: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let plainColor: Color
    let displayNamesByUsername: [String: String]
    var onMentionTap: ((String) -> Void)?
    var displayNamesByUserId: [UUID: String] = [:]

    func makeCoordinator() -> Coordinator {
        Coordinator(onMentionTap: onMentionTap)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = IntrinsicHeightTextView()
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.isUserInteractionEnabled = true
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.dataDetectorTypes = []
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        applyContent(to: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.onMentionTap = onMentionTap
        applyContent(to: textView)
        textView.invalidateIntrinsicContentSize()
    }

    private func applyContent(to textView: UITextView) {
        let mentionColor = UIColor(SplickTheme.Colors.info)
        textView.linkTextAttributes = [
            .foregroundColor: mentionColor,
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        let attributed = Self.attributedString(
            text: text,
            fontSize: fontSize,
            plainColor: UIColor(plainColor),
            mentionColor: mentionColor,
            displayNamesByUsername: displayNamesByUsername,
            displayNamesByUserId: displayNamesByUserId
        )
        if textView.attributedText != attributed {
            textView.attributedText = attributed
        }
    }

    static func attributedString(
        text: String,
        fontSize: CGFloat,
        plainColor: UIColor,
        mentionColor: UIColor,
        displayNamesByUsername: [String: String],
        displayNamesByUserId: [UUID: String] = [:]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let plainFont = UIFont.systemFont(ofSize: fontSize)
        let mentionFont = UIFont.systemFont(ofSize: fontSize, weight: .semibold)

        for token in FeedTextParser.tokens(in: text) {
            switch token {
            case .plain(let value):
                result.append(NSAttributedString(
                    string: value,
                    attributes: [.font: plainFont, .foregroundColor: plainColor]
                ))
            case .mention(let value):
                let mentionKey = MentionStyler.username(fromMentionToken: value)
                let label = MentionStyler.mentionLabel(
                    token: value,
                    displayNamesByUsername: displayNamesByUsername,
                    displayNamesByUserId: displayNamesByUserId
                )
                var attributes: [NSAttributedString.Key: Any] = [
                    .font: mentionFont,
                    .foregroundColor: mentionColor,
                ]
                if let url = MentionLink.url(token: value) {
                    attributes[.link] = url
                }
                result.append(NSAttributedString(string: label, attributes: attributes))
            case .customEmoji(let shortcode):
                result.append(NSAttributedString(
                    string: ":\(shortcode):",
                    attributes: [.font: plainFont, .foregroundColor: plainColor]
                ))
            }
        }
        return result
    }

    static func displayString(
        text: String,
        displayNamesByUsername: [String: String],
        displayNamesByUserId: [UUID: String] = [:]
    ) -> String {
        attributedString(
            text: text,
            fontSize: 16,
            plainColor: .label,
            mentionColor: .blue,
            displayNamesByUsername: displayNamesByUsername,
            displayNamesByUserId: displayNamesByUserId
        ).string
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onMentionTap: ((String) -> Void)?

        init(onMentionTap: ((String) -> Void)?) {
            self.onMentionTap = onMentionTap
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith url: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            guard interaction == .invokeDefaultAction,
                  let username = MentionLink.username(from: url) else {
                return interaction != .invokeDefaultAction
            }
            onMentionTap?(username)
            return false
        }
    }
}

private final class IntrinsicHeightTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        let fitted = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: ceil(fitted.height))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}
