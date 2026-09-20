import SwiftUI
import Common
import DesignSystem

/// Phone-only field with flag + dial code — matches login `AuthIdentifierField` phone mode.
struct ConnectPhoneNumberField: View {
    @Binding var text: String
    var selectedRegion: PhoneCallingRegion
    var errorMessage: String?
    var placeholder: String
    var cornerRadius: CGFloat = SplickTheme.CornerRadius.control
    var locale: Locale
    var onSelectRegion: (PhoneCallingRegion) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                PhoneCountryCodeMenu(
                    selectedRegion: selectedRegion,
                    locale: locale,
                    onSelect: onSelectRegion
                )

                TextField(placeholder, text: $text)
                    .font(SplickTheme.Typography.body)
                    .focused($isFocused)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            if errorMessage != nil {
                SplickFieldErrorMessage(errorMessage)
            }
        }
    }
}
