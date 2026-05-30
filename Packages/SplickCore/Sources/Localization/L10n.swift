import Foundation

public enum L10n {
    public static func string(_ key: L10nKey, locale: AppLocale) -> String {
        let table = locale == .vi ? StringsVi.values : StringsEn.values
        return table[key] ?? key.rawValue
    }

    public static func format(_ key: L10nKey, locale: AppLocale, _ arguments: CVarArg...) -> String {
        String(format: string(key, locale: locale), arguments: arguments)
    }
}
