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

    public static func detailScreenHeight(safeTop: CGFloat) -> CGFloat {
        safeTop
            + FeedSegmentChromeMetrics.navigationBarHeight
            + fadeTail
    }

    public static func height(for mode: SplickScrollTopFadeOverlay.Mode, safeTop: CGFloat) -> CGFloat {
        switch mode {
        case .feedTab:
            return totalHeight(safeTop: safeTop)
        case .detailScreen:
            return detailScreenHeight(safeTop: safeTop)
        case .compactBelowNav:
            return compactFadeTail
        }
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

/// Gradual top fade when scroll content passes beneath navigation chrome.
public struct SplickScrollTopFadeOverlay: View {
    public enum Mode: Equatable {
        /// Feed / expense tab: safe area + nav bar + segment row + fade tail.
        case feedTab
        /// Push-style detail (post detail): safe area + nav bar + fade tail.
        case detailScreen
        /// Short dissolve below an opaque nav bar.
        case compactBelowNav
    }

    public var mode: Mode

    public init(mode: Mode = .feedTab) {
        self.mode = mode
    }

    public var body: some View {
        GeometryReader { proxy in
            let height = SplickScrollChromeFadeMetrics.height(
                for: mode,
                safeTop: proxy.safeAreaInsets.top
            )
            let usesFullGradient = mode == .feedTab || mode == .detailScreen

            ZStack(alignment: .top) {
                LinearGradient(
                    stops: usesFullGradient
                        ? SplickScrollChromeFadeMetrics.backgroundStops
                        : SplickScrollChromeFadeMetrics.compactBackgroundStops,
                    startPoint: .top,
                    endPoint: .bottom
                )

                if usesFullGradient, #available(iOS 26.0, *) {
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
        .ignoresSafeArea(edges: mode == .compactBelowNav ? [] : .top)
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
