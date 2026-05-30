import SwiftUI
import UIKit

/// Text field that formats VND amounts with "." while typing (not only on blur).
struct LiveVNDMoneyTextField: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont = .systemFont(ofSize: 28, weight: .bold)
    var textColor: UIColor = .label
    var placeholder: String = "0"

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.keyboardType = .numberPad
        field.delegate = context.coordinator
        field.font = font
        field.textColor = textColor
        field.placeholder = placeholder
        field.borderStyle = .none
        field.text = text
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text, !uiView.isFirstResponder {
            uiView.text = text
        }
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
