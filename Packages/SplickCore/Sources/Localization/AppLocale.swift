import Foundation

/// BCP-47 language subtags supported by Splick. Must stay in sync with backend `preferredLocale`.
public enum AppLocale: String, CaseIterable, Codable, Sendable, Identifiable {
    case vi
    case en

    public static let `default`: AppLocale = .vi

    public var id: String { rawValue }

    public var apiCode: String { rawValue }

    public var acceptLanguageHeader: String { rawValue }

    public var displayNameKey: L10nKey {
        switch self {
        case .vi: return .profileLanguageVi
        case .en: return .profileLanguageEn
        }
    }

    public static func from(apiValue: String?) -> AppLocale {
        guard let apiValue else { return .default }
        let normalized = apiValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return AppLocale(rawValue: normalized) ?? .default
    }

    public static func fromDeviceLanguage() -> AppLocale {
        guard let preferred = Locale.preferredLanguages.first?.lowercased() else {
            return .default
        }
        let languageSubtag = preferred.split(separator: "-").first.map(String.init) ?? preferred
        return AppLocale(rawValue: languageSubtag) ?? .default
    }
}
