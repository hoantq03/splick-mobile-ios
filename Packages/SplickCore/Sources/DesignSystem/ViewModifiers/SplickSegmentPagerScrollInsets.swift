import SwiftUI

/// How a segment-pager page sits relative to the navigation / pill chrome.
public enum SplickSegmentPagerTopInsetStyle: Equatable, Sendable {
    /// Content already starts below the nav bar. Tight gap only.
    case tight
    /// Content extends under nav + segment pills (feed / expense pagers).
    case underChrome
}

/// Top content margin so segment-pager tabs (feed / expense) sit correctly under chrome.
public enum SplickSegmentPagerTopInsetMetrics {
    private static let belowSegmentSpacing: CGFloat = SplickTheme.Spacing.lg
    private static let toolbarBuffer: CGFloat = SplickTheme.Spacing.sm
    /// Pages whose pager is already laid out below the nav bar.
    public static let tightTopGap: CGFloat = SplickTheme.Spacing.sm

    private static var segmentChromeHeight: CGFloat {
        FeedSegmentChromeMetrics.navigationBarHeight
            + FeedSegmentChromeMetrics.segmentRowHeight
            + toolbarBuffer
    }

    public static var minimumTopGap: CGFloat {
        FeedSegmentChromeMetrics.segmentRowHeight + belowSegmentSpacing
    }

    public static var defaultScrollTopMargin: CGFloat { minimumTopGap }

    public static func resolvedTopMargin(
        for geometry: GeometryProxy,
        style: SplickSegmentPagerTopInsetStyle
    ) -> CGFloat {
        switch style {
        case .tight:
            return tightTopGap
        case .underChrome:
            return resolvedUnderChromeTopMargin(for: geometry)
        }
    }

    private static func resolvedUnderChromeTopMargin(for geometry: GeometryProxy) -> CGFloat {
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
    public func splickSegmentPagerScrollInsets(
        style: SplickSegmentPagerTopInsetStyle = .underChrome
    ) -> some View {
        modifier(SplickSegmentPagerScrollInsetsModifier(style: style))
    }

    /// Top inset for non-scroll pager pages (loading, empty, error).
    public func splickSegmentPagerPageTopInset(
        isEnabled: Bool,
        style: SplickSegmentPagerTopInsetStyle = .underChrome
    ) -> some View {
        modifier(SplickSegmentPagerPageTopInsetModifier(isEnabled: isEnabled, style: style))
    }
}

private struct SplickSegmentPagerScrollInsetsModifier: ViewModifier {
    let style: SplickSegmentPagerTopInsetStyle
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive
    @State private var topMargin: CGFloat

    init(style: SplickSegmentPagerTopInsetStyle) {
        self.style = style
        _topMargin = State(
            initialValue: style == .tight
                ? SplickSegmentPagerTopInsetMetrics.tightTopGap
                : SplickSegmentPagerTopInsetMetrics.defaultScrollTopMargin
        )
    }

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
            if style == .underChrome {
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
    }

    private func applyTopMargin(from geometry: GeometryProxy) {
        guard !pullToRefreshActive else { return }
        let next = SplickSegmentPagerTopInsetMetrics.resolvedTopMargin(for: geometry, style: style)
        guard abs(next - topMargin) > 0.5 else { return }
        topMargin = next
    }
}

private struct SplickSegmentPagerPageTopInsetModifier: ViewModifier {
    let isEnabled: Bool
    let style: SplickSegmentPagerTopInsetStyle
    @State private var topPadding: CGFloat

    init(isEnabled: Bool, style: SplickSegmentPagerTopInsetStyle) {
        self.isEnabled = isEnabled
        self.style = style
        _topPadding = State(
            initialValue: style == .tight
                ? SplickSegmentPagerTopInsetMetrics.tightTopGap
                : SplickSegmentPagerTopInsetMetrics.defaultScrollTopMargin
        )
    }

    func body(content: Content) -> some View {
        content
            .padding(.top, isEnabled ? topPadding : 0)
            .background {
                if isEnabled, style == .underChrome {
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
        let next = SplickSegmentPagerTopInsetMetrics.resolvedTopMargin(for: geometry, style: style)
        guard abs(next - topPadding) > 0.5 else { return }
        topPadding = next
    }
}
