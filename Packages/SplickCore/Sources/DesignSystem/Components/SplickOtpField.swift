import SwiftUI
import UIKit
import Common

/// Six-digit OTP entry with individual boxes. Input is a caret-hidden `UITextField`
/// so the system cursor cannot sit across the whole row (misaligned with the cells).
public struct SplickOtpField: View {
    public static let defaultLength = 6

    @Binding private var code: String
    private let length: Int
    private let errorMessage: String?
    private let autoFocus: Bool
    private let onComplete: ((String) -> Void)?
    private let cornerRadius: CGFloat

    @State private var isFocused = false
    @Environment(\.suppressKeyboardAutoFocus) private var suppressKeyboardAutoFocus
    @Environment(\.usesBrandAuthChrome) private var usesBrandAuthChrome
    @Environment(\.colorScheme) private var colorScheme
    @State private var ignoreKeyboardHideUntil: Date = .distantPast

    private let boxHeight: CGFloat = 56
    private let boxSpacing: CGFloat = 10

    public init(
        code: Binding<String>,
        length: Int = SplickOtpField.defaultLength,
        errorMessage: String? = nil,
        autoFocus: Bool = true,
        cornerRadius: CGFloat = SplickTheme.CornerRadius.control,
        onComplete: ((String) -> Void)? = nil
    ) {
        self._code = code
        self.length = max(4, min(length, 8))
        self.errorMessage = errorMessage
        self.autoFocus = autoFocus
        self.cornerRadius = cornerRadius
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(alignment: .center, spacing: SplickTheme.Spacing.xs) {
            ZStack {
                HStack(spacing: boxSpacing) {
                    ForEach(0..<length, id: \.self) { index in
                        otpBox(at: index)
                    }
                }
                .allowsHitTesting(false)

                HiddenOtpTextField(
                    code: $code,
                    length: length,
                    isFocused: $isFocused,
                    onComplete: onComplete
                )
                .accessibilityLabel("Verification code, \(length) digits")
            }
            .frame(height: boxHeight)
            .clipped()
            .contentShape(Rectangle())
            .accessibilityIdentifier(KeyboardDismissExempt.accessibilityIdentifier)
            .onTapGesture {
                focusFromUserTap()
            }
        }
        .animation(Self.errorReveal, value: errorMessage)
        .onAppear {
            requestFocusIfNeeded()
        }
        .onChange(of: autoFocus) { shouldAutoFocus in
            if shouldAutoFocus {
                requestFocusIfNeeded()
            } else {
                isFocused = false
            }
        }
        .onChange(of: suppressKeyboardAutoFocus) { isSuppressed in
            if isSuppressed {
                isFocused = false
            } else {
                requestFocusIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            guard Date() >= ignoreKeyboardHideUntil else { return }
            isFocused = false
        }
    }

    private static let errorReveal = Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.42)

    private var activeIndex: Int {
        min(code.count, length - 1)
    }

    @ViewBuilder
    private func otpBox(at index: Int) -> some View {
        let digit = digit(at: index)
        let isActive = isFocused && index == activeIndex && code.count < length
        let isFilled = index < code.count

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(boxFill(isFilled: isFilled, isActive: isActive))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(boxStroke(isActive: isActive), lineWidth: isActive ? 2 : 1)

            if digit.isEmpty && isActive {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(usesBrandAuthChrome ? SplickTheme.Colors.brandPink : SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 2, height: 22)
                    .opacity(0.9)
            } else {
                Text(digit)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: boxHeight)
        .animation(.easeOut(duration: 0.15), value: code)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private func boxFill(isFilled: Bool, isActive: Bool) -> Color {
        if errorMessage != nil {
            return SplickTheme.Colors.error.opacity(0.06)
        }
        if usesBrandAuthChrome {
            return SplickTheme.Colors.resolvedAuthFieldFill(colorScheme)
        }
        if isActive {
            return SplickTheme.Colors.primaryGradientStart.opacity(0.08)
        }
        return SplickTheme.Colors.secondaryBackground
    }

    private func boxStroke(isActive: Bool) -> some ShapeStyle {
        if errorMessage != nil {
            return AnyShapeStyle(SplickTheme.Colors.error.opacity(0.85))
        }
        if usesBrandAuthChrome {
            return AnyShapeStyle(
                isActive
                    ? SplickTheme.Colors.authFieldStrokeFocused
                    : SplickTheme.Colors.authFieldStroke
            )
        }
        if isActive {
            return AnyShapeStyle(SplickTheme.Colors.primaryGradient)
        }
        return AnyShapeStyle(SplickTheme.Colors.divider.opacity(0.6))
    }

    private func digit(at index: Int) -> String {
        guard index < code.count else { return "" }
        let stringIndex = code.index(code.startIndex, offsetBy: index)
        return String(code[stringIndex])
    }

    private func requestFocusIfNeeded() {
        guard autoFocus, !suppressKeyboardAutoFocus else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard autoFocus, !suppressKeyboardAutoFocus else { return }
            applyFocus()
        }
    }

    private func focusFromUserTap() {
        guard !suppressKeyboardAutoFocus else { return }
        ignoreKeyboardHideUntil = Date().addingTimeInterval(1)
        applyFocus()
    }

    private func applyFocus() {
        ignoreKeyboardHideUntil = Date().addingTimeInterval(1)
        isFocused = true
    }
}

/// Invisible number-pad field whose caret/selection are forced off so only the
/// per-cell indicator in `SplickOtpField` is visible.
private struct HiddenOtpTextField: UIViewRepresentable {
    @Binding var code: String
    var length: Int
    @Binding var isFocused: Bool
    var onComplete: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(length: length, onComplete: onComplete)
    }

    func makeUIView(context: Context) -> CaretHiddenTextField {
        let field = CaretHiddenTextField()
        field.keyboardType = .numberPad
        field.textContentType = .oneTimeCode
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.smartInsertDeleteType = .no
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.textColor = .clear
        field.tintColor = .clear
        field.font = .systemFont(ofSize: 1)
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged),
            for: .editingChanged
        )
        context.coordinator.field = field
        return field
    }

    func updateUIView(_ uiView: CaretHiddenTextField, context: Context) {
        context.coordinator.length = length
        context.coordinator.onComplete = onComplete
        context.coordinator.codeBinding = $code
        context.coordinator.isFocusedBinding = $isFocused
        if uiView.text != code {
            uiView.text = code
        }
        let shouldFocus = isFocused
        DispatchQueue.main.async {
            if shouldFocus {
                if !uiView.isFirstResponder {
                    uiView.becomeFirstResponder()
                }
            } else if uiView.isFirstResponder {
                uiView.resignFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var length: Int
        var onComplete: ((String) -> Void)?
        var codeBinding: Binding<String>?
        var isFocusedBinding: Binding<Bool>?
        weak var field: UITextField?

        init(length: Int, onComplete: ((String) -> Void)?) {
            self.length = length
            self.onComplete = onComplete
        }

        @objc func editingChanged(_ sender: UITextField) {
            applySanitized(sender.text ?? "")
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFocusedBinding?.wrappedValue = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFocusedBinding?.wrappedValue = false
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let current = textField.text ?? ""
            let nsCurrent = current as NSString
            let next = nsCurrent.replacingCharacters(in: range, with: string)
            applySanitized(next)
            return false
        }

        private func applySanitized(_ raw: String) {
            let trimmed = String(raw.filter(\.isNumber).prefix(length))
            if field?.text != trimmed {
                field?.text = trimmed
            }
            if codeBinding?.wrappedValue != trimmed {
                codeBinding?.wrappedValue = trimmed
            }
            if trimmed.count == length {
                onComplete?(trimmed)
            }
        }
    }
}

private final class CaretHiddenTextField: UITextField {
    override func caretRect(for position: UITextPosition) -> CGRect { .zero }

    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] { [] }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }
}
