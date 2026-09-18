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
        case .fullLockup: 412.0 / 390.0
        case .markOnly: 278.0 / 221.0
        }
    }

    public var body: some View {
        Image(assetName, bundle: .module)
            .resizable()
            .interpolation(.high)
            .renderingMode(.template)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .foregroundStyle(foreground)
    }

    private var foreground: Color {
        switch style {
        case .fullColor, .monochrome:
            SplickTheme.Colors.textPrimary
        case .onDark:
            Color.white
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
        case .fullLockup: size * (390.0 / 412.0)
        case .markOnly: size * (221.0 / 278.0)
        }
    }

    private var appIconCornerRadius: CGFloat { size * 0.2237 }

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
        let markWidth = size * 0.64
        RoundedRectangle(cornerRadius: appIconCornerRadius, style: .continuous)
            .fill(Color.white)
            .overlay {
                Image("SplickLogoMark", bundle: .module)
                    .resizable()
                    .interpolation(.high)
                    .renderingMode(.template)
                    .aspectRatio(278.0 / 221.0, contentMode: .fit)
                    .foregroundStyle(Color.black)
                    .frame(width: markWidth, height: markWidth * (221.0 / 278.0))
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: appIconCornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: size * 0.06, y: size * 0.04)
    }
}
