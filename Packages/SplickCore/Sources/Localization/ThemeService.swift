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

    public init(
        userDefaults: UserDefaultsServiceProtocol,
        storageKey: String = AppConstants.UserDefaults.selectedTheme
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        if let saved: String = userDefaults.get(for: storageKey) {
            self.theme = AppTheme.from(storedValue: saved)
        } else {
            self.theme = .default
        }
        Self.applyUserInterfaceStyle(theme)
    }

    public var preferredColorScheme: ColorScheme? {
        theme.preferredColorScheme
    }

    public func setTheme(_ newTheme: AppTheme) {
        guard newTheme != theme else { return }
        theme = newTheme
        userDefaults.set(newTheme.rawValue, for: storageKey)
        Self.applyUserInterfaceStyle(newTheme)
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
}
