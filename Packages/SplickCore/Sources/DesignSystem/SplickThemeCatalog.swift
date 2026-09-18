import SwiftUI
import UIKit
import Localization

/// Loading-indicator colors for one [SplickVisualTheme].
/// Add a static palette here when introducing a new visual theme.
public struct SplickSpinnerPalette: Equatable {
    public let gradientColors: [Color]
    public let onAccent: Color
    public let refreshTint: UIColor

    public init(gradientColors: [Color], onAccent: Color, refreshTint: UIColor) {
        self.gradientColors = gradientColors
        self.onAccent = onAccent
        self.refreshTint = refreshTint
    }
}

/// Single place to resolve appearance tokens. Views should read palettes from here
/// instead of switching on `AppTheme` or `ColorScheme`.
public enum SplickThemeCatalog {
    public static func spinnerPalette(for theme: SplickVisualTheme) -> SplickSpinnerPalette {
        switch theme {
        case .light:
            return lightSpinner
        case .dark:
            return darkSpinner
        }
    }

    public static func visualTheme(
        preference: AppTheme,
        systemIsDark: Bool
    ) -> SplickVisualTheme {
        preference.visualTheme(systemIsDark: systemIsDark)
    }

    private static let lightSpinner = SplickSpinnerPalette(
        gradientColors: [
            SplickTheme.Colors.brandBlue,
            SplickTheme.Colors.brandPink,
            SplickTheme.Colors.brandOrange,
            SplickTheme.Colors.brandOrange.opacity(0.08),
        ],
        onAccent: .white,
        refreshTint: UIColor(red: 0, green: 149 / 255, blue: 1, alpha: 1)
    )

    /// Same wordmark hues, slightly brighter so the ring reads on dark chrome.
    private static let darkSpinner = SplickSpinnerPalette(
        gradientColors: [
            Color(hex: 0x47B5FF),
            SplickTheme.Colors.brandPink,
            SplickTheme.Colors.brandOrange,
            SplickTheme.Colors.brandOrange.opacity(0.18),
        ],
        onAccent: .white,
        refreshTint: UIColor(red: 71 / 255, green: 181 / 255, blue: 1, alpha: 1)
    )
}

private struct SplickVisualThemeKey: EnvironmentKey {
    static let defaultValue: SplickVisualTheme? = nil
}

extension EnvironmentValues {
    /// Injected from the app root. When nil, [SplickSpinner] falls back to `colorScheme`.
    public var splickVisualTheme: SplickVisualTheme? {
        get { self[SplickVisualThemeKey.self] }
        set { self[SplickVisualThemeKey.self] = newValue }
    }
}

extension View {
    public func splickVisualTheme(_ theme: SplickVisualTheme) -> some View {
        environment(\.splickVisualTheme, theme)
    }
}

extension SplickVisualTheme {
    public static func resolved(
        override: SplickVisualTheme?,
        colorScheme: ColorScheme
    ) -> SplickVisualTheme {
        override ?? (colorScheme == .dark ? .dark : .light)
    }
}
