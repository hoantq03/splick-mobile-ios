import SwiftUI

/// Top content margin so segment-pager tabs (feed / expense) scroll under soft fade chrome
/// instead of sitting under a hard opaque navigation edge.
public enum SplickSegmentPagerTopInsetMetrics {
    private static let belowSegmentSpacing: CGFloat = SplickTheme.Spacing.lg
    private static let toolbarBuffer: CGFloat = SplickTheme.Spacing.sm

    private static var segmentChromeHeight: CGFloat {
        FeedSegmentChromeMetrics.navigationBarHeight
            + FeedSegmentChromeMetrics.segmentRowHeight
            + toolbarBuffer
    }

    public static var minimumTopGap: CGFloat {
        FeedSegmentChromeMetrics.segmentRowHeight + belowSegmentSpacing
    }

    public static var defaultScrollTopMargin: CGFloat { minimumTopGap }

    public static func resolvedTopMargin(for geometry: GeometryProxy) -> CGFloat {
        let globalMinY = geometry.frame(in: .global).minY
        let safeTop = geometry.safeAreaInsets.top
        let chromeBottom = safeTop + segmentChromeHeight

        if globalMinY >= chromeBottom - belowSegmentSpacing {
            return minimumTopGap
        }

        return max(minimumTopGap, chromeBottom - globalMinY + belowSegmentSpacing)
    }
}

extension View {
    /// Keeps scroll content below the inline segment row; pairs with `SplickScrollTopFadeOverlay`.
    public func splickSegmentPagerScrollInsets() -> some View {
        modifier(SplickSegmentPagerScrollInsetsModifier())
    }

    /// Top inset for non-scroll pager pages (loading, empty, error).
    public func splickSegmentPagerPageTopInset(isEnabled: Bool) -> some View {
        modifier(SplickSegmentPagerPageTopInsetModifier(isEnabled: isEnabled))
    }
}

private struct SplickSegmentPagerScrollInsetsModifier: ViewModifier {
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive
    @State private var topMargin: CGFloat = SplickSegmentPagerTopInsetMetrics.defaultScrollTopMargin

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
        let next = SplickSegmentPagerTopInsetMetrics.resolvedTopMargin(for: geometry)
        guard abs(next - topMargin) > 0.5 else { return }
        topMargin = next
    }
}

private struct SplickSegmentPagerPageTopInsetModifier: ViewModifier {
    let isEnabled: Bool
    @State private var topPadding: CGFloat = SplickSegmentPagerTopInsetMetrics.defaultScrollTopMargin

    func body(content: Content) -> some View {
        content
            .padding(.top, isEnabled ? topPadding : 0)
            .background {
                if isEnabled {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                applyTopPadding(from: geometry)
                            }
                            .onChange(of: geometry.frame(in: .global).minY) { _ in
                                applyTopPadding(from: geometry)
                            }
                    }
                }
            }
    }

    private func applyTopPadding(from geometry: GeometryProxy) {
        let next = SplickSegmentPagerTopInsetMetrics.resolvedTopMargin(for: geometry)
        guard abs(next - topPadding) > 0.5 else { return }
        topPadding = next
    }
}
