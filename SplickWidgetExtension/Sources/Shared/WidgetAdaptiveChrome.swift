import SwiftUI
import WidgetKit
import SplickWidgetKit

// MARK: - OS tier

/// Visual tier mapped to major iOS widget design eras supported by Splick.
enum WidgetOSTier: Comparable {
    case legacy      // iOS 16 — solid grouped cards, lock-screen accessories
    case modern      // iOS 17–18 — containerBackground, accented home screen
    case vibrant     // iOS 19–25 — richer materials (fallback to modern APIs)
    case liquidGlass // iOS 26+ — Liquid Glass home screen, glass controls

    static var current: WidgetOSTier {
        if #available(iOS 26.0, *) { return .liquidGlass }
        if #available(iOS 19.0, *) { return .vibrant }
        if #available(iOS 17.0, *) { return .modern }
        return .legacy
    }

    var usesContainerBackground: Bool {
        if #available(iOS 17.0, *) { return self >= .modern }
        return false
    }

    var prefersGlassControls: Bool {
        if #available(iOS 26.0, *) { return self == .liquidGlass }
        return false
    }
}

// MARK: - Container background (widget configuration level)

enum WidgetSurfaceStyle {
    case automatic
    case brandGradient
    case photo
    case clear
}

struct WidgetSurfaceBackground: View {
    let style: WidgetSurfaceStyle

    var body: some View {
        switch WidgetOSTier.current {
        case .legacy:
            legacyBackground
        case .modern, .vibrant:
            modernBackground
        case .liquidGlass:
            liquidGlassBackground
        }
    }

    @ViewBuilder
    private var legacyBackground: some View {
        switch style {
        case .brandGradient:
            WidgetColors.brandGradient
        case .photo, .clear:
            Color(.systemBackground)
        case .automatic:
            Color(.secondarySystemGroupedBackground)
        }
    }

    @ViewBuilder
    private var modernBackground: some View {
        switch style {
        case .brandGradient:
            WidgetColors.brandGradient
        case .photo, .clear:
            Color.clear
        case .automatic:
            Color(.systemBackground)
        }
    }

    @ViewBuilder
    private var liquidGlassBackground: some View {
        // Let the system replace with glass in tinted/clear home-screen modes.
        switch style {
        case .brandGradient:
            WidgetColors.brandGradient.opacity(0.88)
        case .photo, .clear:
            Color.clear
        case .automatic:
            Color.clear
        }
    }
}

extension View {
    func widgetSplickContainerBackground(_ style: WidgetSurfaceStyle = .automatic) -> some View {
        WidgetSplickContainerBackgroundContainer(view: self, style: style)
    }
}

private struct WidgetSplickContainerBackgroundContainer<V: View>: View {
    let view: V
    let style: WidgetSurfaceStyle

    var body: some View {
        if #available(iOS 17.0, *) {
            modernBody
        } else {
            legacyBody
        }
    }

    @available(iOS 17.0, *)
    private var modernBody: some View {
        view.containerBackground(for: .widget) {
            WidgetSurfaceBackground(style: style)
        }
    }

    private var legacyBody: some View {
        ZStack {
            WidgetSurfaceBackground(style: style)
            view
        }
    }
}

// MARK: - In-content card chrome (home-screen widgets)

private struct WidgetInContentBackground: ViewModifier {
    let style: WidgetSurfaceStyle

    func body(content: Content) -> some View {
        switch WidgetOSTier.current {
        case .legacy:
            content
                .background(
                    ContainerRelativeShape()
                        .fill(legacyFill)
                )
        case .modern, .vibrant:
            content
        case .liquidGlass:
            content
        }
    }

    private var legacyFill: some ShapeStyle {
        switch style {
        case .brandGradient:
            AnyShapeStyle(WidgetColors.brandGradient)
        default:
            AnyShapeStyle(Color(.secondarySystemGroupedBackground))
        }
    }
}

extension View {
    func widgetLegacyCardBackground(_ style: WidgetSurfaceStyle = .automatic) -> some View {
        modifier(WidgetInContentBackground(style: style))
    }
}

// MARK: - Accented / Liquid Glass content groups

struct WidgetAccentGroup<Content: View>: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 17.0, *), renderingMode == .accented {
            content.widgetAccentable()
        } else {
            content
        }
    }
}

struct WidgetPrimaryGroup<Content: View>: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 17.0, *), renderingMode == .accented {
            content.widgetAccentable(false)
        } else {
            content
        }
    }
}

// MARK: - Typography & controls per tier

struct WidgetTierHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        switch WidgetOSTier.current {
        case .legacy:
            WidgetBrandHeader(title)
        case .modern, .vibrant:
            WidgetBrandHeader(title)
                .font(.caption.weight(.semibold))
        case .liquidGlass:
            if #available(iOS 17.0, *) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2.weight(.bold))
                        .widgetAccentable()
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .widgetAccentable()
                    Spacer(minLength: 0)
                }
                .foregroundStyle(WidgetColors.primaryStart)
            } else {
                WidgetBrandHeader(title)
            }
        }
    }
}

struct WidgetMetricText: View {
    let text: String
    let color: Color

    var body: some View {
        Group {
            switch WidgetOSTier.current {
            case .legacy:
                Text(text)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(color)
            case .modern, .vibrant:
                Text(text)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(color)
            case .liquidGlass:
                if #available(iOS 17.0, *) {
                    Text(text)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                        .widgetAccentable()
                } else {
                    Text(text)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(color)
                }
            }
        }
        .minimumScaleFactor(0.7)
        .lineLimit(1)
    }
}

struct WidgetActionButton: View {
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            label
        }
    }

    @ViewBuilder
    private var label: some View {
        if #available(iOS 26.0, *), WidgetOSTier.current.prefersGlassControls {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        } else if #available(iOS 17.0, *) {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(WidgetColors.primaryStart.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(WidgetColors.primaryStart.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct WidgetCaptureChip: View {
    var body: some View {
        if #available(iOS 26.0, *), WidgetOSTier.current.prefersGlassControls {
            if #available(iOS 17.0, *) {
                VStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.title3.weight(.semibold))
                        .widgetAccentable()
                    Text("Chụp ngay")
                        .font(.caption2.weight(.semibold))
                        .widgetAccentable()
                }
                .frame(width: 88, height: 88)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
            } else {
                legacyChip
            }
        } else if #available(iOS 17.0, *) {
            VStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.title2)
                Text("Chụp ngay")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(width: 88, height: 88)
            .background(WidgetColors.brandGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            legacyChip
        }
    }

    private var legacyChip: some View {
        VStack(spacing: 6) {
            Image(systemName: "camera.fill")
                .font(.title3)
            Text("Chụp ngay")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(width: 84, height: 84)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(WidgetColors.brandGradient)
        )
    }
}

struct WidgetCaptureHero: View {
    var body: some View {
        if #available(iOS 26.0, *), WidgetOSTier.current.prefersGlassControls {
            if #available(iOS 17.0, *) {
                VStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .widgetAccentable()
                    Text("Chia sẻ ngay")
                        .font(.headline.weight(.bold))
                        .widgetAccentable()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            } else {
                legacyCaptureHero
            }
        } else if #available(iOS 17.0, *) {
            VStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 34, weight: .semibold))
                Text("Chia sẻ ngay")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WidgetColors.brandGradient)
            .clipShape(ContainerRelativeShape())
        } else {
            legacyCaptureHero
        }
    }

    private var legacyCaptureHero: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.system(size: 32, weight: .semibold))
            Text("Chia sẻ ngay")
                .font(.subheadline.weight(.bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ContainerRelativeShape()
                .fill(WidgetColors.brandGradient)
        )
    }
}

extension Image {
    @ViewBuilder
    func widgetPhotoRendering() -> some View {
        if #available(iOS 18.0, *) {
            self.widgetAccentedRenderingMode(.fullColor)
        } else {
            self
        }
    }
}
