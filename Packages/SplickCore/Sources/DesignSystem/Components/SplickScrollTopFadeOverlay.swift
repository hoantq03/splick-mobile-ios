import SwiftUI

public enum SplickScrollChromeFadeMetrics {
    /// Extra fade tail below the segment pills so content dissolves gradually.
    public static let fadeTail: CGFloat = 56
    /// Short dissolve when the overlay sits *below* the nav bar.
    public static let compactFadeTail: CGFloat = 36

    public static func totalHeight(safeTop: CGFloat) -> CGFloat {
        safeTop
            + FeedSegmentChromeMetrics.navigationBarHeight
            + FeedSegmentChromeMetrics.segmentRowHeight
            + fadeTail
    }

    private static var backgroundColor: Color {
        SplickTheme.Colors.background
    }

    public static var backgroundStops: [Gradient.Stop] {
        let bg = backgroundColor
        return [
            .init(color: bg, location: 0),
            .init(color: bg.opacity(0.98), location: 0.18),
            .init(color: bg.opacity(0.88), location: 0.38),
            .init(color: bg.opacity(0.62), location: 0.58),
            .init(color: bg.opacity(0.32), location: 0.78),
            .init(color: bg.opacity(0.08), location: 0.92),
            .init(color: bg.opacity(0), location: 1)
        ]
    }

    public static var materialMaskStops: [Gradient.Stop] {
        [
            .init(color: .black, location: 0),
            .init(color: .black.opacity(0.92), location: 0.22),
            .init(color: .black.opacity(0.68), location: 0.46),
            .init(color: .black.opacity(0.34), location: 0.68),
            .init(color: .black.opacity(0.10), location: 0.86),
            .init(color: .black.opacity(0.02), location: 0.96),
            .init(color: .clear, location: 1)
        ]
    }

    public static var compactBackgroundStops: [Gradient.Stop] {
        let bg = backgroundColor
        return [
            .init(color: bg.opacity(0.42), location: 0),
            .init(color: bg.opacity(0.22), location: 0.4),
            .init(color: bg.opacity(0.08), location: 0.72),
            .init(color: bg.opacity(0), location: 1)
        ]
    }
}

/// Gradual top fade when scroll content passes beneath segment navigation chrome.
public struct SplickScrollTopFadeOverlay: View {
    /// When true, overlay sits *below* the nav bar — short dissolve, no opaque band.
    public var compact: Bool

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public var body: some View {
        GeometryReader { proxy in
            let height = compact
                ? SplickScrollChromeFadeMetrics.compactFadeTail
                : SplickScrollChromeFadeMetrics.totalHeight(safeTop: proxy.safeAreaInsets.top)

            ZStack(alignment: .top) {
                LinearGradient(
                    stops: compact
                        ? SplickScrollChromeFadeMetrics.compactBackgroundStops
                        : SplickScrollChromeFadeMetrics.backgroundStops,
                    startPoint: .top,
                    endPoint: .bottom
                )

                if !compact {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .mask {
                            LinearGradient(
                                stops: SplickScrollChromeFadeMetrics.materialMaskStops,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                }
            }
            .frame(height: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .compositingGroup()
        }
        .allowsHitTesting(false)
        .ignoresSafeArea(edges: compact ? [] : .top)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Hides iOS 26's hard scroll-edge band; `SplickScrollTopFadeOverlay` provides the soft dissolve.
    @ViewBuilder
    public func splickScrollSoftTopEdge() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectHidden(true, for: .top)
        } else {
            self
        }
    }
}
