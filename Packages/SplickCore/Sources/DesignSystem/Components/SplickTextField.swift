import SwiftUI

public struct SplickTextField: View {
    private let placeholder: String
    @Binding private var text: String
    private let isSecure: Bool
    private let errorMessage: String?
    private let icon: String?
    private let validationStatus: FieldValidationStatus
    private let onValidationAccessoryTap: (() -> Void)?
    private let requirementItems: [PasswordRequirementGuideItem]
    private let requirementIntro: String?
    private let overlayNote: String?
    private let cornerRadius: CGFloat
    private let showsPasswordVisibilityToggle: Bool
    private let passwordVisibleAccessibilityLabel: String
    private let passwordHiddenAccessibilityLabel: String
    private let externalPasswordVisible: Binding<Bool>?

    @State private var internalPasswordVisible = false
    @State private var noteDismissed = false
    @State private var lingerComplete = false
    @State private var fieldHeight: CGFloat = 48
    @FocusState private var isFieldFocused: Bool
    @Environment(\.usesBrandAuthChrome) private var usesBrandAuthChrome
    @Environment(\.colorScheme) private var colorScheme

    private static let accessorySide: CGFloat = 20
    private static let visibilityToggleAnimation = Animation.easeInOut(duration: 0.22)
    private static let errorReveal = Animation.spring(
        response: 0.34,
        dampingFraction: 0.92,
        blendDuration: 0.08
    )

    private static let guideAnimation = Animation.spring(response: 0.32, dampingFraction: 0.86)

    public init(
        _ placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        errorMessage: String? = nil,
        icon: String? = nil,
        validationStatus: FieldValidationStatus = .neutral,
        onValidationAccessoryTap: (() -> Void)? = nil,
        requirementItems: [PasswordRequirementGuideItem] = [],
        requirementIntro: String? = nil,
        overlayNote: String? = nil,
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
        self.requirementItems = requirementItems
        self.requirementIntro = requirementIntro
        self.overlayNote = overlayNote
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

                if showsWarningAccessory {
                    warningAccessory
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.72).combined(with: .opacity),
                                removal: .scale(scale: 0.84).combined(with: .opacity)
                            )
                        )
                }

                if isSecure, showsPasswordVisibilityToggle {
                    passwordVisibilityButton
                }

                trailingValidationAccessory
            }
            .padding(SplickTheme.Spacing.sm)
            .background(fieldFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(fieldStroke, lineWidth: usesBrandAuthChrome && isFieldFocused ? 1.5 : 1)
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: PasswordFieldHeightKey.self, value: geo.size.height)
                }
            )
            .tint(usesBrandAuthChrome ? SplickTheme.Colors.brandBlue : SplickTheme.Colors.primary)

            if errorMessage != nil {
                SplickFieldErrorMessage(errorMessage)
                    .transition(Self.errorTransition)
            }
        }
        .overlay(alignment: .top) {
            if popupVisible {
                Group {
                    if guideVisible {
                        PasswordRequirementsOverlayCard(intro: requirementIntro, items: requirementItems)
                    } else if let overlayNote, !overlayNote.isEmpty {
                        PasswordMessageOverlayCard(message: overlayNote)
                    }
                }
                    .padding(.top, fieldHeight + 8)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                        )
                    )
            }
        }
        .zIndex(popupVisible ? 12 : 0)
        .animation(Self.errorReveal, value: errorMessage)
        .animation(Self.guideAnimation, value: popupVisible)
        .animation(Self.guideAnimation, value: showsWarningAccessory)
        .animation(Self.guideAnimation, value: requirementItems)
        .animation(Self.guideAnimation, value: overlayNote)
        .onPreferenceChange(PasswordFieldHeightKey.self) { fieldHeight = $0 }
        .onChange(of: text.isEmpty) { isEmpty in
            if isEmpty { noteDismissed = false }
        }
        .onChange(of: overlayNote) { note in
            if let note, !note.isEmpty { noteDismissed = false }
        }
        .onChange(of: allRequirementsMet) { met in
            handleRequirementsCompletion(met)
        }
    }

    private var allRequirementsMet: Bool {
        !requirementItems.isEmpty && requirementItems.allSatisfy(\.met)
    }

    private var guideVisible: Bool {
        guard !requirementItems.isEmpty, !text.isEmpty, !noteDismissed else { return false }
        return !allRequirementsMet || lingerComplete
    }

    private var hasOverlayIssue: Bool {
        guard let overlayNote, !overlayNote.isEmpty else { return false }
        return !text.isEmpty
    }

    private var overlayVisible: Bool {
        hasOverlayIssue && !noteDismissed
    }

    private var popupVisible: Bool {
        guideVisible || overlayVisible
    }

    private var showsWarningAccessory: Bool {
        if !requirementItems.isEmpty {
            return guideVisible
        }
        if hasOverlayIssue {
            return true
        }
        return validationStatus == .warning
    }

    private var showsValidCheck: Bool {
        guard !popupVisible else { return false }
        if !requirementItems.isEmpty {
            return allRequirementsMet && !text.isEmpty
        }
        return validationStatus == .valid
    }

    private var fieldFill: Color {
        if usesBrandAuthChrome {
            return SplickTheme.Colors.resolvedAuthFieldFill(colorScheme)
        }
        return SplickTheme.Colors.secondaryBackground
    }

    private var fieldStroke: Color {
        if errorMessage != nil {
            return SplickTheme.Colors.error
        }
        if popupVisible {
            return SplickTheme.Colors.warning
        }
        guard usesBrandAuthChrome else { return .clear }
        return isFieldFocused
            ? SplickTheme.Colors.authFieldStrokeFocused
            : SplickTheme.Colors.authFieldStroke
    }

    private static let errorTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .offset(y: -8)),
        removal: .opacity.combined(with: .offset(y: -6))
    )

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
    private var warningAccessory: some View {
        Button {
            if !requirementItems.isEmpty || hasOverlayIssue {
                withAnimation(Self.guideAnimation) {
                    noteDismissed.toggle()
                }
            } else {
                onValidationAccessoryTap?()
            }
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: Self.accessorySide))
                .foregroundStyle(SplickTheme.Colors.warning)
                .frame(width: Self.accessorySide, height: Self.accessorySide)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Password requirements")
        .disabled(requirementItems.isEmpty && !hasOverlayIssue && onValidationAccessoryTap == nil)
    }

    @ViewBuilder
    private var trailingValidationAccessory: some View {
        switch validationStatus {
        case .loading:
            SplickSpinner(size: .small)
                .frame(width: Self.accessorySide, height: Self.accessorySide)
                .accessibilityLabel("Checking")
        case .valid, .warning, .neutral:
            if showsValidCheck {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: Self.accessorySide))
                    .foregroundStyle(SplickTheme.Colors.success)
                    .frame(width: Self.accessorySide, height: Self.accessorySide)
                    .accessibilityLabel("Valid")
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func handleRequirementsCompletion(_ met: Bool) {
        guard met, !text.isEmpty, !noteDismissed else {
            lingerComplete = false
            return
        }
        lingerComplete = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            withAnimation(Self.guideAnimation) {
                lingerComplete = false
            }
        }
    }
}

private struct PasswordFieldHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 48
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct PasswordRequirementsOverlayCard: View {
    let intro: String?
    let items: [PasswordRequirementGuideItem]

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            if let intro, !intro.isEmpty {
                Text(intro)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            ForEach(items) { item in
                HStack(spacing: SplickTheme.Spacing.sm) {
                    Image(systemName: item.met ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            item.met ? SplickTheme.Colors.success : SplickTheme.Colors.textTertiary
                        )
                        .scaleEffect(item.met ? 1 : 0.92)
                        .animation(
                            .spring(response: 0.28, dampingFraction: 0.72),
                            value: item.met
                        )
                    Text(item.label)
                        .font(SplickTheme.Typography.body)
                        .fontWeight(item.met ? .medium : .regular)
                        .foregroundStyle(
                            item.met ? SplickTheme.Colors.textPrimary : SplickTheme.Colors.textSecondary
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SplickTheme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(SplickTheme.Colors.divider.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
    }
}

private struct PasswordMessageOverlayCard: View {
    let message: String

    var body: some View {
        Text(message)
            .font(SplickTheme.Typography.body)
            .foregroundStyle(SplickTheme.Colors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SplickTheme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(SplickTheme.Colors.divider.opacity(0.55), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
    }
}
