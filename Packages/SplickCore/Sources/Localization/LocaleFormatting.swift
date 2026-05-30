import Foundation

public enum LocaleFormatting {
    public static func locale(for appLocale: AppLocale) -> Locale {
        Locale(identifier: appLocale.rawValue)
    }

    public static func currency(code: String, appLocale: AppLocale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = locale(for: appLocale)
        return formatter
    }

    public static func relativeDate(_ date: Date, appLocale: AppLocale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale(for: appLocale)
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
