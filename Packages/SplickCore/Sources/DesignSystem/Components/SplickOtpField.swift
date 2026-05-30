import SwiftUI

/// Six-digit OTP entry with individual boxes and hidden `TextField` for keyboard / SMS autofill.
public struct SplickOtpField: View {
    public static let defaultLength = 6

    @Binding private var code: String
    private let length: Int
    private let errorMessage: String?
    private let autoFocus: Bool
    private let onComplete: ((String) -> Void)?

    @FocusState private var isFocused: Bool

    private let boxHeight: CGFloat = 56
    private let boxSpacing: CGFloat = 10

    public init(
        code: Binding<String>,
        length: Int = SplickOtpField.defaultLength,
        errorMessage: String? = nil,
        autoFocus: Bool = true,
        onComplete: ((String) -> Void)? = nil
    ) {
        self._code = code
        self.length = max(4, min(length, 8))
        self.errorMessage = errorMessage
        self.autoFocus = autoFocus
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            GeometryReader { geometry in
                let boxWidth = boxWidth(for: geometry.size.width)

                ZStack {
                    TextField("", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($isFocused)
                        .opacity(0.02)
                        .frame(maxWidth: .infinity, minHeight: boxHeight)
                        .accessibilityLabel("Verification code, \(length) digits")

                    HStack(spacing: boxSpacing) {
                        ForEach(0..<length, id: \.self) { index in
                            otpBox(at: index, width: boxWidth)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: boxHeight)
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
            }
            .frame(height: boxHeight)

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
            }
        }
        .onAppear {
            guard autoFocus else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
        .onChange(of: code) { newValue in
            let digits = newValue.filter(\.isNumber)
            let trimmed = String(digits.prefix(length))
            if trimmed != code {
                code = trimmed
            }
            if trimmed.count == length {
                onComplete?(trimmed)
            }
        }
    }

    private func boxWidth(for totalWidth: CGFloat) -> CGFloat {
        let spacing = boxSpacing * CGFloat(length - 1)
        let computed = (totalWidth - spacing) / CGFloat(length)
        return min(52, max(40, computed))
    }

    private var activeIndex: Int {
        min(code.count, length - 1)
    }

    @ViewBuilder
    private func otpBox(at index: Int, width: CGFloat) -> some View {
        let digit = digit(at: index)
        let isActive = isFocused && index == activeIndex && code.count < length
        let isFilled = index < code.count

        ZStack {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous)
                .fill(boxFill(isFilled: isFilled, isActive: isActive))

            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous)
                .strokeBorder(boxStroke(isActive: isActive), lineWidth: isActive ? 2 : 1)

            if digit.isEmpty && isActive {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 2, height: 22)
                    .opacity(0.9)
            } else {
                Text(digit)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .monospacedDigit()
            }
        }
        .frame(width: width, height: boxHeight)
        .animation(.easeOut(duration: 0.15), value: code)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private func boxFill(isFilled: Bool, isActive: Bool) -> Color {
        if errorMessage != nil {
            return SplickTheme.Colors.error.opacity(0.06)
        }
        if isActive {
            return SplickTheme.Colors.primaryGradientStart.opacity(0.08)
        }
        if isFilled {
            return SplickTheme.Colors.secondaryBackground
        }
        return SplickTheme.Colors.secondaryBackground
    }

    private func boxStroke(isActive: Bool) -> some ShapeStyle {
        if errorMessage != nil {
            return AnyShapeStyle(SplickTheme.Colors.error.opacity(0.85))
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
}
