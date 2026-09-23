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
    var maximumNumberOfLines: Int = 0
    var onTruncationChange: ((Bool) -> Void)?
    var onPlainTap: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onMentionTap: onMentionTap, onPlainTap: onPlainTap)
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
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        textView.addGestureRecognizer(tap)
        applyContent(to: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.onMentionTap = onMentionTap
        context.coordinator.onPlainTap = onPlainTap
        if textView.textContainer.maximumNumberOfLines != maximumNumberOfLines {
            textView.textContainer.maximumNumberOfLines = maximumNumberOfLines
            textView.textContainer.lineBreakMode = maximumNumberOfLines > 0
                ? .byTruncatingTail
                : .byWordWrapping
        }
        applyContent(to: textView)
        textView.invalidateIntrinsicContentSize()
        if context.coordinator.appliedText != text
            || context.coordinator.appliedLineLimit != maximumNumberOfLines {
            context.coordinator.appliedText = text
            context.coordinator.appliedLineLimit = maximumNumberOfLines
            context.coordinator.lastReportedTruncation = nil
        }
        let report = { self.reportTruncation(of: textView, coordinator: context.coordinator) }
        (textView as? IntrinsicHeightTextView)?.onLayout = report
        report()
    }

    private func reportTruncation(of textView: UITextView, coordinator: Coordinator) {
        guard maximumNumberOfLines > 0, let onTruncationChange else { return }
        let width = textView.bounds.width
        guard width > 1, let attributed = textView.attributedText else { return }
        let truncated = Self.isTruncated(
            attributed: attributed,
            width: width,
            maximumLines: maximumNumberOfLines
        )
        guard coordinator.lastReportedTruncation != truncated else { return }
        coordinator.lastReportedTruncation = truncated
        DispatchQueue.main.async {
            onTruncationChange(truncated)
        }
    }

    private static func isTruncated(
        attributed: NSAttributedString,
        width: CGFloat,
        maximumLines: Int
    ) -> Bool {
        let storage = NSTextStorage(attributedString: attributed)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = maximumLines
        container.lineBreakMode = .byTruncatingTail
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        let glyphRange = layout.glyphRange(for: container)
        let characterRange = layout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        return NSMaxRange(characterRange) < attributed.length
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

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var onMentionTap: ((String) -> Void)?
        var onPlainTap: (() -> Void)?
        var lastReportedTruncation: Bool?
        var appliedText: String?
        var appliedLineLimit: Int?

        init(onMentionTap: ((String) -> Void)?, onPlainTap: (() -> Void)? = nil) {
            self.onMentionTap = onMentionTap
            self.onPlainTap = onPlainTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let textView = gesture.view as? UITextView else { return }
            let location = gesture.location(in: textView)
            let inset = textView.textContainerInset
            let point = CGPoint(
                x: location.x - inset.left - textView.textContainer.lineFragmentPadding,
                y: location.y - inset.top
            )
            var fraction: CGFloat = 0
            let characterIndex = textView.layoutManager.characterIndex(
                for: point,
                in: textView.textContainer,
                fractionOfDistanceBetweenInsertionPoints: &fraction
            )
            let textLength = textView.attributedText?.length ?? 0
            if textLength > 0, characterIndex < textLength,
               let url = textView.attributedText.attribute(.link, at: characterIndex, effectiveRange: nil) as? URL,
               let username = MentionLink.username(from: url) {
                onMentionTap?(username)
                return
            }
            onPlainTap?()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith url: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            interaction != .invokeDefaultAction
        }
    }
}

private final class IntrinsicHeightTextView: UITextView {
    var onLayout: (() -> Void)?

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        let fitted = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: ceil(fitted.height))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
        onLayout?()
    }
}
