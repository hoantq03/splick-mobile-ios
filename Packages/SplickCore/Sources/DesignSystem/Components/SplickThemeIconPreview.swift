import SwiftUI
import Localization

/// Home-screen icon preview shown in theme settings.
public struct SplickThemeIconPreview: View {
    public var theme: AppTheme
    public var size: CGFloat

    public init(theme: AppTheme, size: CGFloat = 36) {
        self.theme = theme
        self.size = size
    }

    public var body: some View {
        switch theme {
        case .light:
            icon(dark: false)
        case .dark:
            icon(dark: true)
        case .system:
            ZStack {
                icon(dark: false)
                    .offset(x: -size * 0.18)
                icon(dark: true)
                    .offset(x: size * 0.18)
            }
            .frame(width: size * 1.36, height: size)
        }
    }

    private func icon(dark: Bool) -> some View {
        Image(dark ? "SplickAppIconDark" : "SplickAppIcon", bundle: .module)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
    }
}
