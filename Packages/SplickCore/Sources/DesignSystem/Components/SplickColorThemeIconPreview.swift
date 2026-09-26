import SwiftUI
import Localization

/// Home-screen icon preview shown in color-theme settings.
public struct SplickColorThemeIconPreview: View {
    public var theme: SplickColorTheme
    public var size: CGFloat

    public init(theme: SplickColorTheme, size: CGFloat = 36) {
        self.theme = theme
        self.size = size
    }

    public var body: some View {
        ZStack {
            icon(asset: theme.previewDarkAssetName)
                .offset(x: size * 0.18)
            icon(asset: theme.previewLightAssetName)
                .offset(x: -size * 0.18)
        }
        .frame(width: size * 1.36, height: size)
    }

    private func icon(asset: String) -> some View {
        Image(asset, bundle: .module)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
    }
}
