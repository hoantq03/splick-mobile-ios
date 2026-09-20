import SwiftUI
import UIKit
import Common
import DesignSystem

struct AuthIdentifierField: View {
    @Binding var text: String
    var intent: LoginIdentifierKind
    var selectedRegion: PhoneCallingRegion
    var errorMessage: String?
    var validationStatus: FieldValidationStatus
    var placeholder: String
    var cornerRadius: CGFloat
    var locale: Locale
    var onSelectRegion: (PhoneCallingRegion) -> Void
    var onSubmit: () -> Void

    @FocusState private var isFocused: Bool
    @Environment(\.usesBrandAuthChrome) private var usesBrandAuthChrome
    @Environment(\.colorScheme) private var colorScheme

    private var isPhoneIntent: Bool { intent == .phone }

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                leadingAccessory

                TextField(placeholder, text: $text)
                    .id("auth.identifier.text")
                    .font(SplickTheme.Typography.body)
                    .focused($isFocused)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .onSubmit(onSubmit)
                    .frame(maxWidth: .infinity, alignment: .leading)

                validationAccessory
            }
            .animation(AuthFlowMotion.countryCodeReveal, value: isPhoneIntent)
            .padding(SplickTheme.Spacing.sm)
            .background(
                usesBrandAuthChrome
                    ? SplickTheme.Colors.resolvedAuthFieldFill(colorScheme)
                    : SplickTheme.Colors.secondaryBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(identifierStroke, lineWidth: usesBrandAuthChrome && isFocused ? 1.5 : 1)
            }
            .tint(usesBrandAuthChrome ? SplickTheme.Colors.brandBlue : SplickTheme.Colors.primary)

            if errorMessage != nil {
                SplickFieldErrorMessage(errorMessage)
            }
        }
    }

    private var identifierStroke: Color {
        if errorMessage != nil {
            return SplickTheme.Colors.error
        }
        guard usesBrandAuthChrome else { return .clear }
        return isFocused
            ? SplickTheme.Colors.authFieldStrokeFocused
            : SplickTheme.Colors.authFieldStroke
    }

    @ViewBuilder
    private var leadingAccessory: some View {
        if isPhoneIntent {
            PhoneCountryCodeMenu(
                selectedRegion: selectedRegion,
                locale: locale,
                onSelect: onSelectRegion
            )
            .transition(AuthFlowMotion.countryCodeTransition)
        } else {
            Image(systemName: intent == .email ? "envelope" : "person")
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(width: 20)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var validationAccessory: some View {
        ZStack {
            SplickSpinner(size: .small)
                .opacity(validationStatus == .loading ? 1 : 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(SplickTheme.Colors.success)
                .opacity(validationStatus == .valid ? 1 : 0)
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(validationStatus == .neutral)
    }
}
