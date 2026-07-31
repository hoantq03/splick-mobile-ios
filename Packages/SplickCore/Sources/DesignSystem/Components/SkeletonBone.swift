import SwiftUI

// MARK: - Shared shimmer phase

private struct SkeletonShimmerPhaseKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var skeletonShimmerPhase: CGFloat {
        get { self[SkeletonShimmerPhaseKey.self] }
        set { self[SkeletonShimmerPhaseKey.self] = newValue }
    }
}

/// Drives a single shimmer clock for descendant `SkeletonBone` views.
public struct SkeletonShimmerHost<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let progress = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.35) / 1.35
            content
                .environment(\.skeletonShimmerPhase, progress)
        }
    }
}

// MARK: - Bone

/// Soft placeholder block with a subtle shimmer — building block for skeleton screens.
public struct SkeletonBone: View {
    public enum ShapeStyle {
        case rectangle(cornerRadius: CGFloat)
        case circle
    }

    @Environment(\.skeletonShimmerPhase) private var shimmerPhase
    @Environment(\.colorScheme) private var colorScheme

    private let width: CGFloat?
    private let height: CGFloat?
    private let shape: ShapeStyle

    public init(
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        shape: ShapeStyle = .rectangle(cornerRadius: SplickTheme.CornerRadius.small)
    ) {
        self.width = width
        self.height = height
        self.shape = shape
    }

    public var body: some View {
        filledShape
            .overlay { shimmerOverlay }
            .mask(filledShape)
            .frame(
                maxWidth: width == nil ? .infinity : width,
                maxHeight: height == nil ? .infinity : height,
                alignment: .leading
            )
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var filledShape: some View {
        switch shape {
        case .rectangle(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(baseFill)
        case .circle:
            Circle()
                .fill(baseFill)
        }
    }

    private var baseFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.10)
    }

    private var shimmerOverlay: some View {
        let highlight = colorScheme == .dark
            ? Color.white.opacity(0.22)
            : Color.white.opacity(0.55)
        return LinearGradient(
            colors: [.clear, highlight, .clear],
            startPoint: UnitPoint(x: shimmerPhase - 0.4, y: 0.5),
            endPoint: UnitPoint(x: shimmerPhase + 0.4, y: 0.5)
        )
    }
}

extension SkeletonBone {
    /// Circular avatar placeholder matching `AvatarView.Size.small` (32pt).
    public static func avatar(size: CGFloat = 32) -> SkeletonBone {
        SkeletonBone(width: size, height: size, shape: .circle)
    }
}
