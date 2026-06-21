import SwiftUI

public struct SplickTextField: View {
    private let placeholder: String
    @Binding private var text: String
    private let isSecure: Bool
    private let errorMessage: String?
    private let icon: String?
    private let validationStatus: FieldValidationStatus
    private let onValidationAccessoryTap: (() -> Void)?
    private let cornerRadius: CGFloat
    private let showsPasswordVisibilityToggle: Bool
    private let passwordVisibleAccessibilityLabel: String
    private let passwordHiddenAccessibilityLabel: String
    private let externalPasswordVisible: Binding<Bool>?

    @State private var internalPasswordVisible = false

    public init(
        _ placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        errorMessage: String? = nil,
        icon: String? = nil,
        validationStatus: FieldValidationStatus = .neutral,
        onValidationAccessoryTap: (() -> Void)? = nil,
        cornerRadius: CGFloat = SplickTheme.CornerRadius.control,
        showsPasswordVisibilityToggle: Bool = false,
        isPasswordVisible: Binding<Bool>? = nil,
        passwordVisibleAccessibilityLabel: String = "Show password",
        passwordHiddenAccessibilityLabel: String = "Hide password"
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.errorMessage = errorMessage
        self.icon = icon
        self.validationStatus = validationStatus
        self.onValidationAccessoryTap = onValidationAccessoryTap
        self.cornerRadius = cornerRadius
        self.showsPasswordVisibilityToggle = showsPasswordVisibilityToggle
        self.externalPasswordVisible = isPasswordVisible
        self.passwordVisibleAccessibilityLabel = passwordVisibleAccessibilityLabel
        self.passwordHiddenAccessibilityLabel = passwordHiddenAccessibilityLabel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .frame(width: 20)
                }

                Group {
                    if isSecure, showsPasswordVisibilityToggle, passwordVisibleBinding.wrappedValue {
                        TextField(placeholder, text: $text)
                    } else if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSecure, showsPasswordVisibilityToggle {
                    Button {
                        passwordVisibleBinding.wrappedValue.toggle()
                    } label: {
                        Image(systemName: passwordVisibleBinding.wrappedValue ? "eye.slash" : "eye")
                            .font(.system(size: 18))
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        passwordVisibleBinding.wrappedValue
                            ? passwordHiddenAccessibilityLabel
                            : passwordVisibleAccessibilityLabel
                    )
                }

                validationAccessory
            }
            .padding(SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        errorMessage != nil ? SplickTheme.Colors.error : Color.clear,
                        lineWidth: 1
                    )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
            }
        }
    }

    private var passwordVisibleBinding: Binding<Bool> {
        externalPasswordVisible ?? $internalPasswordVisible
    }

    @ViewBuilder
    private var validationAccessory: some View {
        switch validationStatus {
        case .neutral:
            EmptyView()
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(SplickTheme.Colors.success)
                .accessibilityLabel("Valid")
        case .warning:
            Button {
                onValidationAccessoryTap?()
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(SplickTheme.Colors.warning)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Password requirements")
            .disabled(onValidationAccessoryTap == nil)
        }
    }
}
