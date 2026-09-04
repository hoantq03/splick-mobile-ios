import Foundation
import Common
import Storage

@MainActor
public final class LanguageService: ObservableObject, LocaleHeaderProviding {
    @Published public private(set) var locale: AppLocale

    private let userDefaults: UserDefaultsServiceProtocol
    private let storageKey: String

    public init(
        userDefaults: UserDefaultsServiceProtocol,
        storageKey: String = AppConstants.UserDefaults.preferredLocale
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        if let saved: String = userDefaults.get(for: storageKey),
           let parsed = AppLocale(rawValue: saved) {
            self.locale = parsed
        } else {
            self.locale = AppLocale.fromDeviceLanguage()
        }
        SplickRelativeDateFormatters.apply(locale: Locale(identifier: locale.rawValue))
    }

    public func text(_ key: L10nKey) -> String {
        L10n.string(key, locale: locale)
    }

    public func format(_ key: L10nKey, _ arguments: CVarArg...) -> String {
        String(format: L10n.string(key, locale: locale), arguments: arguments)
    }

    public func passwordRuleText(_ rule: PasswordRule) -> String {
        switch rule {
        case .minLength:
            return format(.authPasswordRuleMinLength, AppConstants.Validation.minPasswordLength)
        case .uppercase:
            return text(.authPasswordRuleUppercase)
        case .lowercase:
            return text(.authPasswordRuleLowercase)
        case .digit:
            return text(.authPasswordRuleDigit)
        case .specialCharacter:
            return text(.authPasswordRuleSpecial)
        }
    }

    public func weakPasswordMessage(for result: PasswordStrengthResult) -> String? {
        guard !result.isStrong, !result.failedRules.isEmpty else { return nil }
        let details = result.failedRules.map(passwordRuleText).joined(separator: ", ")
        return format(.authPasswordWeakMissing, details)
    }

    public func compactRelativeTime(from date: Date, relativeTo now: Date = .now) -> String {
        LocaleFormatting.compactRelativeDate(date, appLocale: locale, now: now)
    }

    public func localizedMessage(for error: Error) -> String {
        APIErrorLocalization.message(for: error, locale: locale)
    }

    public func setLocale(_ newLocale: AppLocale, persist: Bool = true) {
        locale = newLocale
        SplickRelativeDateFormatters.apply(locale: Locale(identifier: newLocale.rawValue))
        if persist {
            userDefaults.set(newLocale.rawValue, for: storageKey)
        }
    }

    public func applyFromServer(_ apiValue: String?) {
        setLocale(AppLocale.from(apiValue: apiValue))
    }

    public nonisolated func acceptLanguageHeader() async -> String {
        await MainActor.run { locale.acceptLanguageHeader }
    }
}
