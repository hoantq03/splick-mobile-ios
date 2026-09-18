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

    private var isPhoneIntent: Bool { intent == .phone }

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                leadingAccessory

                TextField(placeholder, text: $text)
                    .id("auth.identifier.text")
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
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        errorMessage != nil ? SplickTheme.Colors.error : Color.clear,
                        lineWidth: 1
                    )
            }

            if errorMessage != nil {
                SplickFieldErrorMessage(errorMessage)
            }
        }
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
            ProgressView()
                .controlSize(.small)
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

private struct PhoneCountryCodeMenu: View {
    let selectedRegion: PhoneCallingRegion
    let locale: Locale
    let onSelect: (PhoneCallingRegion) -> Void

    var body: some View {
        Menu {
            ForEach(PhoneCallingCodeTable.regionsForPicker(locale: locale)) { region in
                Button {
                    onSelect(region)
                } label: {
                    Text("\(region.flagEmoji)  \(region.displayLabel(locale: locale))")
                }
            }
        } label: {
            HStack(spacing: SplickTheme.Spacing.xxs) {
                Text(selectedRegion.flagEmoji)
                    .font(.system(size: 18))
                Text("+\(selectedRegion.callingCode)")
                    .font(SplickTheme.Typography.captionBold)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selectedRegion.displayLabel(locale: locale))
    }
}
