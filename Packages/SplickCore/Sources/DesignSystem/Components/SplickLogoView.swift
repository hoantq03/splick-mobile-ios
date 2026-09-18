import SwiftUI

public enum SplickLogoStyle {
    case fullColor
    case monochrome
    case onDark
}

/// `markOnly` — camera mark; `fullLockup` — camera + Splick wordmark.
public enum SplickLogoLayout {
    case markOnly
    case fullLockup
}

public struct SplickLogoView: View {
    public var layout: SplickLogoLayout
    public var style: SplickLogoStyle

    public init(layout: SplickLogoLayout = .markOnly, style: SplickLogoStyle = .fullColor) {
        self.layout = layout
        self.style = style
    }

    private var assetName: String {
        layout == .fullLockup ? "SplickLogoFull" : "SplickLogoMark"
    }

    private var aspectRatio: CGFloat {
        switch layout {
        case .fullLockup: 1289.0 / 1220.0
        case .markOnly: 1
        }
    }

    public var body: some View {
        let image = Image(assetName, bundle: .module)
            .renderingMode(style == .fullColor ? .original : .template)
            .interpolation(.high)
            .resizable()
            .aspectRatio(aspectRatio, contentMode: .fit)

        switch style {
        case .fullColor:
            image
        case .monochrome:
            image.foregroundStyle(SplickTheme.Colors.textPrimary)
        case .onDark:
            image.foregroundStyle(Color.white)
        }
    }
}

/// Sized brand logo (onboarding, splash, auth).
public struct SplickLogoMark: View {
    public var layout: SplickLogoLayout
    public var style: SplickLogoStyle
    /// Square side for `markOnly`; max width for `fullLockup`.
    public var size: CGFloat
    /// Home-screen application icon chrome (continuous rounded square).
    public var asAppIcon: Bool

    public init(
        size: CGFloat = 120,
        layout: SplickLogoLayout = .markOnly,
        style: SplickLogoStyle = .fullColor,
        asAppIcon: Bool = false
    ) {
        self.size = size
        self.layout = layout
        self.style = style
        self.asAppIcon = asAppIcon
    }

    private var frameHeight: CGFloat {
        switch layout {
        case .fullLockup: size * (1220.0 / 1289.0)
        case .markOnly: size
        }
    }

    public var body: some View {
        Group {
            if asAppIcon {
                appIconBody
            } else {
                SplickLogoView(layout: layout, style: style)
                    .frame(width: size, height: frameHeight)
            }
        }
        .accessibilityLabel("Splick")
    }

    private var appIconBody: some View {
        Image("SplickAppIcon", bundle: .module)
            .renderingMode(.original)
            .interpolation(.high)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: Color.black.opacity(0.10), radius: size * 0.08, y: size * 0.04)
    }
}
