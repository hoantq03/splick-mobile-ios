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
    }

    public func text(_ key: L10nKey) -> String {
        L10n.string(key, locale: locale)
    }

    public func format(_ key: L10nKey, _ arguments: CVarArg...) -> String {
        String(format: L10n.string(key, locale: locale), arguments: arguments)
    }

    public func localizedMessage(for error: Error) -> String {
        APIErrorLocalization.message(for: error, locale: locale)
    }

    public func setLocale(_ newLocale: AppLocale, persist: Bool = true) {
        locale = newLocale
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
