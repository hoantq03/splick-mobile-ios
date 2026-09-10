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
    @FocusState private var isFieldFocused: Bool

    private static let accessorySide: CGFloat = 20
    private static let visibilityToggleAnimation = Animation.easeInOut(duration: 0.22)

    public init(
        _ placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        errorMessage: String? = nil,
        icon: String? = nil,
        validationStatus: FieldValidationStatus = .neutral,
        onValidationAccessoryTap: (() -> Void)? = nil,
        cornerRadius: CGFloat = SplickTheme.CornerRadius.control,
        showsPasswordVisibilityToggle: Bool = true,
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
                        .frame(width: Self.accessorySide)
                }

                secureAwareInput
                    .focused($isFieldFocused)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSecure, showsPasswordVisibilityToggle {
                    passwordVisibilityButton
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

    private var isPasswordVisible: Bool {
        passwordVisibleBinding.wrappedValue
    }

    private var passwordVisibleBinding: Binding<Bool> {
        externalPasswordVisible ?? $internalPasswordVisible
    }

    @ViewBuilder
    private var secureAwareInput: some View {
        Group {
            if isSecure, showsPasswordVisibilityToggle, isPasswordVisible {
                TextField(placeholder, text: $text)
                    .transition(.opacity)
            } else if isSecure {
                SecureField(placeholder, text: $text)
                    .transition(.opacity)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .animation(Self.visibilityToggleAnimation, value: isPasswordVisible)
    }

    private var passwordVisibilityButton: some View {
        Button {
            withAnimation(Self.visibilityToggleAnimation) {
                passwordVisibleBinding.wrappedValue.toggle()
            }
            // Keep keyboard focus after SecureField ↔ TextField swap.
            Task { @MainActor in
                isFieldFocused = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(SplickTheme.Colors.textSecondary.opacity(0.12))

                Image(systemName: "eye.fill")
                    .opacity(isPasswordVisible ? 0 : 1)
                    .scaleEffect(isPasswordVisible ? 0.72 : 1)
                    .rotationEffect(.degrees(isPasswordVisible ? -12 : 0))

                Image(systemName: "eye.slash.fill")
                    .opacity(isPasswordVisible ? 1 : 0)
                    .scaleEffect(isPasswordVisible ? 1 : 0.72)
                    .rotationEffect(.degrees(isPasswordVisible ? 0 : 12))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .frame(width: Self.accessorySide, height: Self.accessorySide)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isPasswordVisible
                ? passwordHiddenAccessibilityLabel
                : passwordVisibleAccessibilityLabel
        )
    }

    @ViewBuilder
    private var validationAccessory: some View {
        switch validationStatus {
        case .neutral:
            EmptyView()
        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(width: Self.accessorySide, height: Self.accessorySide)
                .accessibilityLabel("Checking")
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: Self.accessorySide))
                .foregroundStyle(SplickTheme.Colors.success)
                .frame(width: Self.accessorySide, height: Self.accessorySide)
                .accessibilityLabel("Valid")
        case .warning:
            Button {
                onValidationAccessoryTap?()
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: Self.accessorySide))
                    .foregroundStyle(SplickTheme.Colors.warning)
                    .frame(width: Self.accessorySide, height: Self.accessorySide)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Password requirements")
            .disabled(onValidationAccessoryTap == nil)
        }
    }
}
