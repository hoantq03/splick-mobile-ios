import Foundation

/// Named brand look (app icon family, buttons, accent colors).
/// Appearance (light/dark) is [AppTheme]; add a case here when shipping a new pack.
public enum SplickColorTheme: String, CaseIterable, Codable, Sendable, Identifiable {
    case `default`

    public var id: String { rawValue }

    public var displayNameKey: L10nKey {
        switch self {
        case .default: return .profileColorThemeDefault
        }
    }

    /// `nil` keeps the primary `AppIcon`. Dark default uses the existing alternate icon.
    public func alternateIconName(isDark: Bool) -> String? {
        switch self {
        case .default:
            return isDark ? AppTheme.darkAlternateIconName : nil
        }
    }

    public var previewLightAssetName: String {
        switch self {
        case .default: return "SplickAppIcon"
        }
    }

    public var previewDarkAssetName: String {
        switch self {
        case .default: return "SplickAppIconDark"
        }
    }

    public static func from(storedValue: String?) -> SplickColorTheme {
        guard let storedValue else { return .default }
        let normalized = storedValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return SplickColorTheme(rawValue: normalized) ?? .default
    }
}
