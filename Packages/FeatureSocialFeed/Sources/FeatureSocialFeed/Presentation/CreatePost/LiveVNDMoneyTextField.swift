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
        let field = UITextField()
        field.keyboardType = .numberPad
        field.delegate = context.coordinator
        field.font = font
        field.textColor = textColor
        field.backgroundColor = .clear
        field.attributedPlaceholder = attributedPlaceholder
        field.borderStyle = .none
        field.text = text
        field.contentVerticalAlignment = .top
        field.setContentHuggingPriority(.defaultLow, for: .vertical)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        uiView.font = font
        uiView.textColor = textColor
        uiView.attributedPlaceholder = attributedPlaceholder
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

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: LiveVNDMoneyTextField

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
