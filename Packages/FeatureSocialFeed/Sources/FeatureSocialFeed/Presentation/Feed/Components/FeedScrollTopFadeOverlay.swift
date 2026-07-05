import SwiftUI
import DesignSystem

enum FeedScrollChromeFadeMetrics {
    /// Extra fade tail below the segment pills so content dissolves gradually.
    static let fadeTail: CGFloat = 56

    static func totalHeight(safeTop: CGFloat) -> CGFloat {
        safeTop
            + FeedSegmentChromeMetrics.navigationBarHeight
            + FeedSegmentChromeMetrics.segmentRowHeight
            + fadeTail
    }

    private static var backgroundColor: Color {
        SplickTheme.Colors.background
    }

    static var backgroundStops: [Gradient.Stop] {
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

    static var materialMaskStops: [Gradient.Stop] {
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
}

/// Gradual top fade when pager content scrolls beneath the feed navigation chrome.
struct FeedScrollTopFadeOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let height = FeedScrollChromeFadeMetrics.totalHeight(
                safeTop: proxy.safeAreaInsets.top
            )

            ZStack(alignment: .top) {
                LinearGradient(
                    stops: FeedScrollChromeFadeMetrics.backgroundStops,
                    startPoint: .top,
                    endPoint: .bottom
                )

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask {
                        LinearGradient(
                            stops: FeedScrollChromeFadeMetrics.materialMaskStops,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
            .frame(height: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .compositingGroup()
        }
        .allowsHitTesting(false)
        .ignoresSafeArea(edges: .top)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Hides iOS 26's hard scroll-edge band; `FeedScrollTopFadeOverlay` provides the soft dissolve.
    @ViewBuilder
    func feedScrollSoftTopEdge() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectHidden(true, for: .top)
        } else {
            self
        }
    }
}
