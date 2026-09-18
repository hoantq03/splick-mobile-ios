import SwiftUI
import Localization

/// Circular loader using the active [SplickVisualTheme] spinner palette.
public struct SplickSpinner: View {
    public enum Size {
        case small
        case medium
        case large

        var dimension: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 28
            case .large: return 40
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 2.75
            case .large: return 3.25
            }
        }
    }

    public var size: Size
    public var usesBrandColors: Bool
    private let sideOverride: CGFloat?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.splickVisualTheme) private var visualThemeOverride

    public init(size: Size = .medium, usesBrandColors: Bool = true, side: CGFloat? = nil) {
        self.size = size
        self.usesBrandColors = usesBrandColors
        self.sideOverride = side
    }

    private var dimension: CGFloat {
        sideOverride ?? size.dimension
    }

    private var strokeWidth: CGFloat {
        if let sideOverride {
            return max(2.4, sideOverride * 0.09)
        }
        return size.lineWidth
    }

    private var palette: SplickSpinnerPalette {
        SplickThemeCatalog.spinnerPalette(
            for: .resolved(override: visualThemeOverride, colorScheme: colorScheme)
        )
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let cycle = 0.9
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: cycle) / cycle
            ring
                .rotationEffect(.degrees(phase * 360))
        }
        .frame(width: dimension, height: dimension)
        .accessibilityLabel("Loading")
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private var ring: some View {
        if usesBrandColors {
            Circle()
                .trim(from: 0.04, to: 0.78)
                .stroke(
                    AngularGradient(
                        colors: palette.gradientColors,
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
        } else {
            Circle()
                .trim(from: 0.04, to: 0.78)
                .stroke(
                    palette.onAccent,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
        }
    }
}

public struct SplickProgressViewStyle: ProgressViewStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        SplickProgressViewStyleBody()
    }
}

private struct SplickProgressViewStyleBody: View {
    @Environment(\.controlSize) private var controlSize

    var body: some View {
        SplickSpinner(size: spinnerSize)
    }

    private var spinnerSize: SplickSpinner.Size {
        switch controlSize {
        case .mini, .small:
            return .small
        case .large:
            return .large
        default:
            return .medium
        }
    }
}
