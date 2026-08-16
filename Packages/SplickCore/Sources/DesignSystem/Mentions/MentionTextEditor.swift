import SwiftUI
import UIKit

/// Multiline editor that styles `@username` while typing (bold blue).
public struct MentionTextEditor: UIViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var minHeight: CGFloat
    var placeholder: String
    var isFocused: Bool

    /// Horizontal padding shared with `MentionTextField` placeholder.
    public static let textInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)

    /// Compact single-line fields (comment composer, expense description) center text vertically.
    static let compactHeightThreshold: CGFloat = 48
    /// Prevents `safeAreaInset` from stretching the comment field to the remaining screen height.
    static let compactMaxHeight: CGFloat = 120
    static let expandedMaxHeight: CGFloat = 220

    static func textInsets(minHeight: CGFloat) -> UIEdgeInsets {
        let vertical: CGFloat = minHeight <= compactHeightThreshold ? 0 : 10
        return UIEdgeInsets(top: vertical, left: 12, bottom: vertical, right: 12)
    }

    public init(
        text: Binding<String>,
        fontSize: CGFloat = 13,
        minHeight: CGFloat = 36,
        placeholder: String = "",
        isFocused: Bool = false
    ) {
        _text = text
        self.fontSize = fontSize
        self.minHeight = minHeight
        self.placeholder = placeholder
        self.isFocused = isFocused
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeUIView(context: Context) -> UITextView {
        let textView = CompactCenteredTextView()
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = .label
        textView.textContainerInset = Self.textInsets(minHeight: minHeight)
        textView.textContainer.lineFragmentPadding = 0
        textView.contentInsetAdjustmentBehavior = .never
        textView.compactMinHeight = minHeight
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.applyStyles(to: textView, text: text)
        return textView
    }

    public func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        uiView.textContainer.lineFragmentPadding = 0
        if let compactView = uiView as? CompactCenteredTextView {
            compactView.compactMinHeight = minHeight
        }

        if minHeight > Self.compactHeightThreshold {
            uiView.textContainerInset = Self.textInsets(minHeight: minHeight)
        }

        // Sync programmatic updates (e.g. reply prefill `@username`) even while focused.
        if context.coordinator.lastSyncedText != text {
            context.coordinator.applyStyles(to: uiView, text: text)
        }

        if isFocused {
            context.coordinator.managesExternalFocus = true
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        } else if context.coordinator.managesExternalFocus, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }

        (uiView as? CompactCenteredTextView)?.applyCompactVerticalCentering()
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let fallbackWidth = max(120, UIScreen.main.bounds.width - 120)
        let proposedWidth = proposal.width ?? fallbackWidth
        let clampedWidth = (proposedWidth.isFinite && proposedWidth > 40) ? proposedWidth : fallbackWidth
        let maxHeight = minHeight <= Self.compactHeightThreshold
            ? Self.compactMaxHeight
            : max(minHeight, Self.expandedMaxHeight)

        if let compactView = uiView as? CompactCenteredTextView,
           minHeight <= Self.compactHeightThreshold {
            let insets = uiView.textContainerInset
            let containerWidth = max(
                1,
                clampedWidth - insets.left - insets.right - uiView.textContainer.lineFragmentPadding * 2
            )
            uiView.textContainer.size = CGSize(width: containerWidth, height: .greatestFiniteMagnitude)
            let used = compactView.textBlockHeight()
            let lineHeight = uiView.font?.lineHeight ?? UIFont.systemFont(ofSize: fontSize).lineHeight
            let rawHeight = used <= lineHeight * 1.5
                ? minHeight
                : used + 16
            let height = min(max(minHeight, rawHeight), maxHeight)
            uiView.isScrollEnabled = rawHeight > maxHeight + 0.5
            return CGSize(width: clampedWidth, height: height)
        }

        let fitting = uiView.sizeThatFits(
            CGSize(width: clampedWidth, height: .greatestFiniteMagnitude)
        )
        let rawHeight = max(minHeight, fitting.height)
        let height = min(rawHeight, maxHeight)
        uiView.isScrollEnabled = rawHeight > maxHeight + 0.5
        return CGSize(width: clampedWidth, height: height)
    }

    public final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MentionTextEditor
        var lastSyncedText: String = ""
        private var isApplyingStyles = false
        /// Tracks whether SwiftUI ever requested external focus control (avoids dismissing keyboard on default `.constant(false)`).
        var managesExternalFocus = false

        init(parent: MentionTextEditor) {
            self.parent = parent
        }

        public func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingStyles else { return }
            let plain = textView.text ?? ""
            parent.text = plain
            lastSyncedText = plain
            applyStyles(to: textView, text: plain)
            (textView as? CompactCenteredTextView)?.applyCompactVerticalCentering()
        }

        func applyStyles(to textView: UITextView, text: String) {
            let previousSynced = lastSyncedText
            let selected = textView.selectedRange
            isApplyingStyles = true
            if text.isEmpty {
                textView.attributedText = nil
                textView.text = ""
                textView.font = .systemFont(ofSize: parent.fontSize)
                textView.textColor = .label
            } else {
                textView.attributedText = MentionStyler.attributedString(
                    text: text,
                    fontSize: parent.fontSize
                )
            }
            lastSyncedText = text
            let length = (textView.text as NSString).length
            if text != previousSynced, text.hasPrefix("@") {
                textView.selectedRange = NSRange(location: length, length: 0)
            } else {
                let location = min(selected.location, max(0, length))
                let lengthClamped = min(selected.length, max(0, length - location))
                textView.selectedRange = NSRange(location: location, length: lengthClamped)
            }
            isApplyingStyles = false
            (textView as? CompactCenteredTextView)?.applyCompactVerticalCentering()
        }
    }
}

/// Centers a single line in a compact pill field; top-aligns once the field grows.
private final class CompactCenteredTextView: UITextView {
    var compactMinHeight: CGFloat = 36

    override func layoutSubviews() {
        super.layoutSubviews()
        applyCompactVerticalCentering()
    }

    func textBlockHeight() -> CGFloat {
        let fontLine = font?.lineHeight ?? UIFont.systemFont(ofSize: 14).lineHeight
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else {
            return ceil(fontLine)
        }
        return max(ceil(layoutManager.usedRect(for: textContainer).height), ceil(fontLine))
    }

    func applyCompactVerticalCentering() {
        guard compactMinHeight <= MentionTextEditor.compactHeightThreshold else { return }
        let usedHeight = textBlockHeight()
        let lineHeight = font?.lineHeight ?? UIFont.systemFont(ofSize: 14).lineHeight
        // Center within the compact pill height, never the stretched SwiftUI bounds
        // (safeAreaInset can propose the remaining screen height).
        let leftover = usedHeight <= lineHeight * 1.5
            ? max(0, compactMinHeight - usedHeight)
            : 0
        let top = leftover > 0 ? floor(leftover / 2) : 0
        let bottom = leftover > 0 ? leftover - top : 0
        let inset = UIEdgeInsets(top: top, left: 12, bottom: bottom, right: 12)
        if textContainerInset != inset {
            textContainerInset = inset
        }
    }
}

/// SwiftUI wrapper with optional placeholder overlay.
public struct MentionTextField: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    var fontSize: CGFloat = 13
    var minHeight: CGFloat = 36

    public init(
        _ placeholder: String,
        text: Binding<String>,
        isFocused: Binding<Bool> = .constant(false),
        fontSize: CGFloat = 13,
        minHeight: CGFloat = 36
    ) {
        self.placeholder = placeholder
        _text = text
        _isFocused = isFocused
        self.fontSize = fontSize
        self.minHeight = minHeight
    }

    private var isCompactField: Bool {
        minHeight <= MentionTextEditor.compactHeightThreshold
    }

    public var body: some View {
        ZStack(alignment: isCompactField ? .leading : .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(Font(UIFont.systemFont(ofSize: fontSize)))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                    .padding(.horizontal, MentionTextEditor.textInsets.left)
                    .padding(.top, isCompactField ? 0 : MentionTextEditor.textInsets(minHeight: minHeight).top)
                    .padding(.bottom, isCompactField ? 0 : MentionTextEditor.textInsets(minHeight: minHeight).bottom)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
            }

            MentionTextEditor(
                text: $text,
                fontSize: fontSize,
                minHeight: minHeight,
                placeholder: placeholder,
                isFocused: isFocused
            )
        }
        .frame(minHeight: minHeight, maxHeight: maxFieldHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var maxFieldHeight: CGFloat {
        isCompactField
            ? MentionTextEditor.compactMaxHeight
            : max(minHeight, MentionTextEditor.expandedMaxHeight)
    }
}
