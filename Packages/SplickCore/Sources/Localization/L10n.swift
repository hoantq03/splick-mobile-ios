import Foundation

public enum L10n {
    private static func table(for locale: AppLocale) -> [L10nKey: String] {
        switch locale {
        case .vi:
            return StringsVi.values.merging(StringsFeatureVi.values, uniquingKeysWith: { _, new in new })
        case .en:
            return StringsEn.values.merging(StringsFeatureEn.values, uniquingKeysWith: { _, new in new })
        }
    }

    public static func string(_ key: L10nKey, locale: AppLocale) -> String {
        table(for: locale)[key] ?? key.rawValue
    }

    public static func format(_ key: L10nKey, locale: AppLocale, _ arguments: CVarArg...) -> String {
        String(format: string(key, locale: locale), arguments: arguments)
    }
}
