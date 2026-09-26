import SwiftUI
import UIKit

/// Text field that formats VND amounts with "," grouping while typing (not only on blur).
struct LiveVNDMoneyTextField: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont = .systemFont(ofSize: 28, weight: .bold)
    var textColor: UIColor = .label
    var placeholder: String = "0"
    var placeholderColor: UIColor = .placeholderText

    func makeUIView(context: Context) -> UITextField {
        let field = BoundedMoneyTextField()
        field.keyboardType = .numberPad
        field.delegate = context.coordinator
        field.font = font
        field.textColor = textColor
        field.backgroundColor = .clear
        field.attributedPlaceholder = attributedPlaceholder
        field.borderStyle = .none
        field.text = text
        field.contentVerticalAlignment = .center
        context.coordinator.appliedPlaceholder = placeholder
        // A flexible text field inside the bill ScrollView is offered unlimited
        // height and keeps expanding, which freezes the screen on push.
        field.setContentHuggingPriority(.required, for: .vertical)
        field.setContentCompressionResistancePriority(.required, for: .vertical)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        if uiView.font?.pointSize != font.pointSize || uiView.font?.fontName != font.fontName {
            uiView.font = font
        }
        if uiView.textColor?.isEqual(textColor) != true {
            uiView.textColor = textColor
        }
        if context.coordinator.appliedPlaceholder != placeholder {
            uiView.attributedPlaceholder = attributedPlaceholder
            context.coordinator.appliedPlaceholder = placeholder
        }
        if uiView.text != text, !uiView.isFirstResponder {
            uiView.text = text
        }
    }

    private var attributedPlaceholder: NSAttributedString {
        NSAttributedString(
            string: placeholder,
            attributes: [
                .font: font,
                .foregroundColor: placeholderColor,
            ]
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// Keeps a finite height so a parent ScrollView cannot grow this field forever.
    private final class BoundedMoneyTextField: UITextField {
        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: ceil(font?.lineHeight ?? 22))
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: LiveVNDMoneyTextField
        var appliedPlaceholder: String?

        init(parent: LiveVNDMoneyTextField) {
            self.parent = parent
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let current = textField.text ?? ""
            guard let textRange = Range(range, in: current) else { return false }

            let proposed = current.replacingCharacters(in: textRange, with: string)
            let formatted = VNDMoneyFormat.sanitizedInput(from: proposed)

            parent.text = formatted
            textField.text = formatted
            return false
        }
    }
}
