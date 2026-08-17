import SwiftUI

/// Top scroll margin for push-style detail screens (post detail) under a transparent nav bar.
public enum SplickDetailScrollInsetMetrics {
    private static let topGap: CGFloat = SplickTheme.Spacing.sm

    public static func resolvedTopMargin(for geometry: GeometryProxy) -> CGFloat {
        let globalMinY = geometry.frame(in: .global).minY
        let safeTop = geometry.safeAreaInsets.top
        let chromeBottom = safeTop + FeedSegmentChromeMetrics.navigationBarHeight

        if globalMinY >= chromeBottom - topGap {
            return topGap
        }

        return max(topGap, chromeBottom - globalMinY + topGap)
    }
}

extension View {
    /// Keeps scroll content below the inline nav bar; pairs with `SplickScrollTopFadeOverlay(mode: .detailScreen)`.
    public func splickDetailScrollInsets() -> some View {
        modifier(SplickDetailScrollInsetsModifier())
    }
}

private struct SplickDetailScrollInsetsModifier: ViewModifier {
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive
    @State private var topMargin: CGFloat = SplickTheme.Spacing.sm

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 17.0, *) {
                content.contentMargins(.top, topMargin, for: .scrollContent)
            } else {
                content.padding(.top, topMargin)
            }
        }
        .scrollContentBackground(.hidden)
        .background(SplickTheme.Colors.background)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        applyTopMargin(from: geometry)
                    }
                    .onChange(of: geometry.frame(in: .global).minY) { _ in
                        applyTopMargin(from: geometry)
                    }
            }
        }
    }

    private func applyTopMargin(from geometry: GeometryProxy) {
        guard !pullToRefreshActive else { return }
        let next = SplickDetailScrollInsetMetrics.resolvedTopMargin(for: geometry)
        guard abs(next - topMargin) > 0.5 else { return }
        topMargin = next
    }
}
