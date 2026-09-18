import Foundation
import SwiftUI
import UIKit
import Common
import Storage

@MainActor
public final class ThemeService: ObservableObject {
    @Published public private(set) var theme: AppTheme

    private let userDefaults: UserDefaultsServiceProtocol
    private let storageKey: String
    private let sharedDefaults: UserDefaults?

    public init(
        userDefaults: UserDefaultsServiceProtocol,
        storageKey: String = AppConstants.UserDefaults.selectedTheme,
        sharedDefaults: UserDefaults? = UserDefaults(suiteName: AppConstants.UserDefaults.appGroup)
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.sharedDefaults = sharedDefaults
        let stored = Self.readStoredTheme(
            userDefaults: userDefaults,
            sharedDefaults: sharedDefaults,
            storageKey: storageKey
        )
        let resolved = AppTheme.from(storedValue: stored)
        self.theme = resolved
        if let stored {
            Self.persistPlainString(
                AppTheme.from(storedValue: stored).rawValue,
                to: sharedDefaults,
                key: storageKey
            )
        }
        Self.applyUserInterfaceStyle(resolved)
    }

    public var preferredColorScheme: ColorScheme? {
        theme.preferredColorScheme
    }

    public func setTheme(_ newTheme: AppTheme) {
        guard newTheme != theme else { return }
        theme = newTheme
        userDefaults.set(newTheme.rawValue, for: storageKey)
        Self.persistPlainString(newTheme.rawValue, to: sharedDefaults, key: storageKey)
        Self.applyUserInterfaceStyle(newTheme)
    }

    /// Reloads the preference from the shared suite (parent app / App Clip).
    public func refreshFromStorage() {
        let resolved = AppTheme.from(storedValue: Self.readStoredTheme(
            userDefaults: userDefaults,
            sharedDefaults: sharedDefaults,
            storageKey: storageKey
        ))
        guard resolved != theme else {
            applyUserInterfaceStyle()
            return
        }
        theme = resolved
        applyUserInterfaceStyle()
    }

    /// `preferredColorScheme` does not always update UIKit trait collections (lists, tab chrome,
    /// `UIHostingController` pages). Window override makes `Color(.label)` switch immediately.
    public func applyUserInterfaceStyle() {
        Self.applyUserInterfaceStyle(theme)
    }

    public static func applyUserInterfaceStyle(_ theme: AppTheme) {
        let style: UIUserInterfaceStyle
        switch theme {
        case .system: style = .unspecified
        case .light: style = .light
        case .dark: style = .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if window.overrideUserInterfaceStyle != style {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }

    private static func readStoredTheme(
        userDefaults: UserDefaultsServiceProtocol,
        sharedDefaults: UserDefaults?,
        storageKey: String
    ) -> String? {
        if let shared = sharedDefaults?.string(forKey: storageKey), !shared.isEmpty {
            return shared
        }
        if let saved: String = userDefaults.get(for: storageKey), !saved.isEmpty {
            persistPlainString(AppTheme.from(storedValue: saved).rawValue, to: sharedDefaults, key: storageKey)
            return saved
        }
        return nil
    }

    private static func persistPlainString(_ value: String, to defaults: UserDefaults?, key: String) {
        defaults?.set(value, forKey: key)
    }
}
