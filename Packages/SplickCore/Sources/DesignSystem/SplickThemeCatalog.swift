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

/// Brand colors for one [SplickColorTheme]. Buttons, chrome, and atmosphere read from here.
public struct SplickBrandPalette: Equatable {
    public let brandOrange: Color
    public let brandPink: Color
    public let brandBlue: Color
    public let brandBlueElevated: Color
    public let brandCanvas: Color
    public let brandCanvasDark: Color
    public let primaryGradientMid: Color
    public let primaryGradientEnd: Color
    public let refreshTintLight: UIColor
    public let refreshTintDark: UIColor

    public var accent: Color { brandBlue }

    public var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [brandBlue, primaryGradientMid, primaryGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var brandWordmarkGradient: LinearGradient {
        LinearGradient(
            colors: [brandBlue, brandPink, brandOrange],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    public func resolvedBrandCanvas(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? brandCanvasDark : brandCanvas
    }
}

/// Single place to resolve appearance tokens. Views should read palettes from here
/// instead of switching on `AppTheme` or `ColorScheme`.
public enum SplickThemeCatalog {
    public static func brandPalette(for colorTheme: SplickColorTheme) -> SplickBrandPalette {
        switch colorTheme {
        case .default:
            return defaultBrand
        }
    }

    public static func spinnerPalette(
        for theme: SplickVisualTheme,
        colorTheme: SplickColorTheme = .default
    ) -> SplickSpinnerPalette {
        let brand = brandPalette(for: colorTheme)
        switch theme {
        case .light:
            return SplickSpinnerPalette(
                gradientColors: [
                    brand.brandBlue,
                    brand.brandPink,
                    brand.brandOrange,
                    brand.brandBlue,
                ],
                onAccent: .white,
                refreshTint: brand.refreshTintLight
            )
        case .dark:
            return SplickSpinnerPalette(
                gradientColors: [
                    brand.brandBlueElevated,
                    brand.brandPink,
                    brand.brandOrange,
                    brand.brandBlueElevated,
                ],
                onAccent: .white,
                refreshTint: brand.refreshTintDark
            )
        }
    }

    public static func visualTheme(
        preference: AppTheme,
        systemIsDark: Bool
    ) -> SplickVisualTheme {
        preference.visualTheme(systemIsDark: systemIsDark)
    }

    private static let defaultBrand = SplickBrandPalette(
        brandOrange: SplickTheme.Colors.brandOrange,
        brandPink: SplickTheme.Colors.brandPink,
        brandBlue: SplickTheme.Colors.brandBlue,
        brandBlueElevated: Color(hex: 0x47B5FF),
        brandCanvas: SplickTheme.Colors.brandCanvas,
        brandCanvasDark: SplickTheme.Colors.brandCanvasDark,
        primaryGradientMid: SplickTheme.Colors.primaryGradientMid,
        primaryGradientEnd: SplickTheme.Colors.primaryGradientEnd,
        refreshTintLight: UIColor(red: 0, green: 149 / 255, blue: 1, alpha: 1),
        refreshTintDark: UIColor(red: 71 / 255, green: 181 / 255, blue: 1, alpha: 1)
    )
}

private struct SplickVisualThemeKey: EnvironmentKey {
    static let defaultValue: SplickVisualTheme? = nil
}

private struct SplickColorThemeKey: EnvironmentKey {
    static let defaultValue: SplickColorTheme = .default
}

private struct SplickBrandPaletteKey: EnvironmentKey {
    static let defaultValue = SplickThemeCatalog.brandPalette(for: .default)
}

extension EnvironmentValues {
    /// Injected from the app root. When nil, [SplickSpinner] falls back to `colorScheme`.
    public var splickVisualTheme: SplickVisualTheme? {
        get { self[SplickVisualThemeKey.self] }
        set { self[SplickVisualThemeKey.self] = newValue }
    }

    public var splickColorTheme: SplickColorTheme {
        get { self[SplickColorThemeKey.self] }
        set { self[SplickColorThemeKey.self] = newValue }
    }

    public var splickBrandPalette: SplickBrandPalette {
        get { self[SplickBrandPaletteKey.self] }
        set { self[SplickBrandPaletteKey.self] = newValue }
    }
}

extension View {
    public func splickVisualTheme(_ theme: SplickVisualTheme) -> some View {
        environment(\.splickVisualTheme, theme)
    }

    public func splickColorTheme(_ theme: SplickColorTheme) -> some View {
        environment(\.splickColorTheme, theme)
            .environment(\.splickBrandPalette, SplickThemeCatalog.brandPalette(for: theme))
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
