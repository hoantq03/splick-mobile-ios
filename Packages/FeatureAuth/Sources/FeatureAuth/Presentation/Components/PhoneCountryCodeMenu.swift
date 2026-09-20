import SwiftUI
import Common
import DesignSystem

/// Flag + dial-code menu shared by login and connect-phone sheets.
struct PhoneCountryCodeMenu: View {
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
            HStack(alignment: .center, spacing: SplickTheme.Spacing.xxs) {
                Text(selectedRegion.flagEmoji)
                    .font(.system(size: 22))
                Text("+\(selectedRegion.callingCode)")
                    .font(SplickTheme.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selectedRegion.displayLabel(locale: locale))
    }
}
