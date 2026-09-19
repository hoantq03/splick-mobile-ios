import Foundation
import SwiftUI

/// Appearance preference persisted locally. Default follows the system.
public enum AppTheme: String, CaseIterable, Codable, Sendable, Identifiable {
    case system
    case light
    case dark

    public static let `default`: AppTheme = .system

    public var id: String { rawValue }

    public var displayNameKey: L10nKey {
        switch self {
        case .system: return .profileThemeSystem
        case .light: return .profileThemeLight
        case .dark: return .profileThemeDark
        }
    }

    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Home-screen icon follows the resolved appearance (light vs dark).
    public func usesDarkAppIcon(systemIsDark: Bool) -> Bool {
        switch self {
        case .system: return systemIsDark
        case .light: return false
        case .dark: return true
        }
    }

    /// Maps the user preference to a visual palette. Add a `SplickVisualTheme` case
    /// when introducing a named look that is not just light/dark.
    public func visualTheme(systemIsDark: Bool) -> SplickVisualTheme {
        usesDarkAppIcon(systemIsDark: systemIsDark) ? .dark : .light
    }

    public static let darkAlternateIconName = "AppIconDark"

    public static func from(storedValue: String?) -> AppTheme {
        guard let storedValue else { return .default }
        let normalized = storedValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return AppTheme(rawValue: normalized) ?? .default
    }
}

/// Resolved look used by design tokens (spinners, chrome). Independent of
/// `AppTheme.system` so new palettes can be added without rewriting views.
public enum SplickVisualTheme: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case light
    case dark

    public var id: String { rawValue }
}
