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
            case .small: return 4.65
            case .medium: return 6.15
            case .large: return 7.1
            }
        }
    }

    public var size: Size
    public var usesBrandColors: Bool
    /// Pull-to-refresh tracking angle. When spinning, rotation continues from this angle.
    public var rotationDegrees: Double?
    /// When true, the ring spins. Defaults to spinning only when `rotationDegrees` is nil.
    public var isSpinning: Bool
    private let sideOverride: CGFloat?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.splickVisualTheme) private var visualThemeOverride
    @Environment(\.splickColorTheme) private var colorTheme
    @State private var spinStartedAt: Date?

    public init(
        size: Size = .medium,
        usesBrandColors: Bool = true,
        side: CGFloat? = nil,
        rotationDegrees: Double? = nil,
        isSpinning: Bool? = nil
    ) {
        self.size = size
        self.usesBrandColors = usesBrandColors
        self.sideOverride = side
        self.rotationDegrees = rotationDegrees
        self.isSpinning = isSpinning ?? (rotationDegrees == nil)
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
            return max(4.65, sideOverride * 0.2)
        }
        return size.lineWidth
    }

    private var palette: SplickSpinnerPalette {
        SplickThemeCatalog.spinnerPalette(
            for: .resolved(override: visualThemeOverride, colorScheme: colorScheme),
            colorTheme: colorTheme
        )
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            ring
                .rotationEffect(.degrees(currentAngle(at: context.date)), anchor: .center)
                .transaction { $0.animation = nil }
        }
        .frame(width: dimension, height: dimension)
        .transaction { $0.animation = nil }
        .onAppear {
            if isSpinning, spinStartedAt == nil {
                spinStartedAt = Date()
            }
        }
        .onChange(of: isSpinning) { spinning in
            spinStartedAt = spinning ? Date() : nil
        }
        .accessibilityLabel("Loading")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var baseAngle: Double {
        rotationDegrees ?? 0
    }

    /// Continues from the pull angle. Never fall back to wall-clock phase — that jumps
    /// the arc the moment loading starts, before `spinStartedAt` is set.
    private func currentAngle(at date: Date) -> Double {
        guard isSpinning else { return baseAngle }
        guard let start = spinStartedAt else { return baseAngle }
        let cycle = 0.9
        let elapsed = date.timeIntervalSince(start)
        let extra = elapsed.truncatingRemainder(dividingBy: cycle) / cycle * 360
        return baseAngle + extra
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
