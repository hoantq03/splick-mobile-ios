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
    /// When set, the ring follows this angle instead of spinning on its own (pull-to-refresh tracking).
    public var rotationDegrees: Double?
    private let sideOverride: CGFloat?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.splickVisualTheme) private var visualThemeOverride

    public init(
        size: Size = .medium,
        usesBrandColors: Bool = true,
        side: CGFloat? = nil,
        rotationDegrees: Double? = nil
    ) {
        self.size = size
        self.usesBrandColors = usesBrandColors
        self.sideOverride = side
        self.rotationDegrees = rotationDegrees
    }

    private var dimension: CGFloat {
        sideOverride ?? size.dimension
    }

    /// Pull distance that rolls the ring through one full turn (arc length = circumference).
    public static func fullRotationPullDistance(for size: Size = .medium) -> CGFloat {
        .pi * size.dimension
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
        Group {
            if let rotationDegrees {
                ring.rotationEffect(.degrees(rotationDegrees))
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                    let cycle = 0.9
                    let phase = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: cycle) / cycle
                    ring
                        .rotationEffect(.degrees(phase * 360))
                }
            }
        }
        .frame(width: dimension, height: dimension)
        .accessibilityLabel("Loading")
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private var ring: some View {
        Circle()
            .trim(from: 0.08, to: 0.92)
            .stroke(
                AngularGradient(
                    colors: usesBrandColors ? palette.gradientColors : [
                        palette.onAccent,
                        palette.onAccent.opacity(0.35),
                        palette.onAccent,
                    ],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
            )
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
