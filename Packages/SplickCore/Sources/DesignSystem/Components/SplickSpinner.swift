import SwiftUI

/// Unified loading indicator — same ring style everywhere; only size / rotation mode differs.
public struct SplickSpinner: View {
    public enum Size {
        case small
        case medium
        case large

        var dimension: CGFloat {
            switch self {
            case .small: 18
            case .medium: 28
            case .large: 40
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .small: 2
            case .medium: 2.5
            case .large: 3
            }
        }
    }

    private let size: Size
    private let rotation: Double
    private let isAnimating: Bool

    /// - Parameters:
    ///   - size: Visual scale (small / medium / large).
    ///   - rotation: Manual rotation in degrees (pull-to-refresh drag). Ignored when `isAnimating` is true.
    ///   - isAnimating: Continuous spin (default). Set false to drive rotation manually.
    public init(size: Size = .medium, rotation: Double = 0, isAnimating: Bool = true) {
        self.size = size
        self.rotation = rotation
        self.isAnimating = isAnimating
    }

    public var body: some View {
        Group {
            if isAnimating {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    ring.rotationEffect(.degrees(continuousAngle(at: timeline.date)))
                }
            } else {
                ring.rotationEffect(.degrees(rotation))
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .accessibilityLabel("Loading")
    }

    private var ring: some View {
        Circle()
            .trim(from: 0.12, to: 0.88)
            .stroke(
                AngularGradient(
                    colors: [
                        SplickTheme.Colors.primaryGradientStart,
                        SplickTheme.Colors.primaryGradientEnd,
                        SplickTheme.Colors.primaryGradientStart.opacity(0.3),
                        SplickTheme.Colors.primaryGradientStart
                    ],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: size.lineWidth, lineCap: .round)
            )
    }

    /// One full turn per second.
    private func continuousAngle(at date: Date) -> Double {
        let seconds = date.timeIntervalSinceReferenceDate
        return seconds.truncatingRemainder(dividingBy: 1.0) * 360
    }
}
