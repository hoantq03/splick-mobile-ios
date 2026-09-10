import SwiftUI

public enum SplickLogoStyle {
    case fullColor
    case monochrome
    case onDark
}

/// `markOnly` — biểu tượng S; `fullLockup` — icon + Splick + Click and Split.
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
        case .fullLockup: 1024.0 / 682.0
        case .markOnly: 900.0 / 1219.0 // transparent mark asset (trimmed)
        }
    }

    public var body: some View {
        Group {
            switch style {
            case .fullColor, .onDark:
                baseImage
            case .monochrome:
                baseImage.saturation(0).contrast(1.05)
            }
        }
    }

    private var baseImage: some View {
        Image(assetName, bundle: .module)
            .resizable()
            .interpolation(.high)
            .aspectRatio(aspectRatio, contentMode: .fit)
    }
}

/// Sized brand logo (onboarding, splash, auth).
public struct SplickLogoMark: View {
    public var layout: SplickLogoLayout
    public var style: SplickLogoStyle
    /// Square side for `markOnly`; max width for `fullLockup`.
    public var size: CGFloat

    public init(
        size: CGFloat = 120,
        layout: SplickLogoLayout = .markOnly,
        style: SplickLogoStyle = .fullColor
    ) {
        self.size = size
        self.layout = layout
        self.style = style
    }

    private var frameHeight: CGFloat {
        switch layout {
        case .fullLockup: size / (1024.0 / 682.0)
        case .markOnly: size * (1219.0 / 900.0)
        }
    }

    public var body: some View {
        SplickLogoView(layout: layout, style: style)
            .frame(width: size, height: frameHeight)
            .accessibilityLabel("Splick")
            .shadow(
                color: SplickTheme.Colors.primaryGradientStart.opacity(
                    style == .fullColor && layout == .markOnly ? 0.18 : 0
                ),
                radius: size * 0.06,
                y: size * 0.03
            )
    }
}
