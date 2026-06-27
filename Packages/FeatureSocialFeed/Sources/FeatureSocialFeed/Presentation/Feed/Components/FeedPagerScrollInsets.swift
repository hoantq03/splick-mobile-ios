import SwiftUI
import DesignSystem

enum FeedPagerTopInsetMetrics {
    /// Gap between the bottom of the inline segment row and the first feed card.
    private static let belowSegmentSpacing: CGFloat = SplickTheme.Spacing.lg

    /// Extra buffer for avatar/bell toolbar row above segment pills.
    private static let toolbarBuffer: CGFloat = SplickTheme.Spacing.sm

    /// Nav bar + inline segment pills (principal toolbar).
    private static var segmentChromeHeight: CGFloat {
        FeedSegmentChromeMetrics.navigationBarHeight
            + FeedSegmentChromeMetrics.segmentRowHeight
            + toolbarBuffer
    }

    /// Minimum top gap even when geometry reports content is already below chrome.
    static var minimumTopGap: CGFloat {
        FeedSegmentChromeMetrics.segmentRowHeight + belowSegmentSpacing
    }

    static var defaultScrollTopMargin: CGFloat { minimumTopGap }

    static func resolvedTopMargin(for geometry: GeometryProxy) -> CGFloat {
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
    /// Keeps scroll content below the inline Chuỗi/Tin/Album segment row.
    func feedPagerScrollInsets() -> some View {
        modifier(FeedPagerScrollInsetsModifier())
    }

    /// Top inset for non-scroll pager pages (loading, empty, error).
    func feedPagerPageTopInset(isEnabled: Bool) -> some View {
        modifier(FeedPagerPageTopInsetModifier(isEnabled: isEnabled))
    }
}

private struct FeedPagerScrollInsetsModifier: ViewModifier {
    @State private var topMargin: CGFloat = FeedPagerTopInsetMetrics.defaultScrollTopMargin

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
        let next = FeedPagerTopInsetMetrics.resolvedTopMargin(for: geometry)
        guard abs(next - topMargin) > 0.5 else { return }
        topMargin = next
    }
}

private struct FeedPagerPageTopInsetModifier: ViewModifier {
    let isEnabled: Bool
    @State private var topPadding: CGFloat = FeedPagerTopInsetMetrics.defaultScrollTopMargin

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
        let next = FeedPagerTopInsetMetrics.resolvedTopMargin(for: geometry)
        guard abs(next - topPadding) > 0.5 else { return }
        topPadding = next
    }
}
