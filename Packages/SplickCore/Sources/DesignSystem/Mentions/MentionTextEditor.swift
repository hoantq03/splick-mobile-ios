import SwiftUI
import UIKit

/// Multiline editor that styles `@username` while typing (bold blue).
public struct MentionTextEditor: UIViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var minHeight: CGFloat
    var placeholder: String
    var isFocused: Bool

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
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = .label
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.applyStyles(to: textView, text: text)
        return textView
    }

    public func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self

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
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? (UIScreen.main.bounds.width - 120)
        let fitting = uiView.sizeThatFits(
            CGSize(width: max(1, width), height: .greatestFiniteMagnitude)
        )
        return CGSize(width: max(1, width), height: max(minHeight, fitting.height))
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
        }

        func applyStyles(to textView: UITextView, text: String) {
            let previousSynced = lastSyncedText
            let selected = textView.selectedRange
            isApplyingStyles = true
            if text.isEmpty {
                textView.attributedText = nil
                textView.text = ""
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

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: fontSize))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
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
        .frame(minHeight: minHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
