import SwiftUI

/// How a segment-pager page sits relative to the navigation / pill chrome.
public enum SplickSegmentPagerTopInsetStyle: Equatable, Sendable {
    /// Nested scroll under a page that already cleared chrome (album grid below the filter).
    case tight
    /// Pager page sits under the transparent nav + inline pills (feed, streak, expense, album).
    case underChrome
}

/// Top content margin so segment-pager tabs sit just below the inline pills.
public enum SplickSegmentPagerTopInsetMetrics {
    private static let belowSegmentSpacing: CGFloat = SplickTheme.Spacing.sm
    /// Matches `FeedNewPostsPillOverlay` — iOS 26 glass bar is taller than the 48pt metric.
    private static var liquidGlassBarExtra: CGFloat {
        if #available(iOS 26.0, *) { 16 } else { 0 }
    }

    /// Pages whose chrome is already accounted for.
    public static let tightTopGap: CGFloat = SplickTheme.Spacing.sm

    /// Pagers ignore the safe area. Pills live in the inline nav — do not add a second pill row.
    public static var underChromeTopGap: CGFloat {
        FeedSegmentChromeMetrics.overlappingNavigationInset
            + belowSegmentSpacing
            + liquidGlassBarExtra
    }

    /// Center the PTR spinner in the band that opens below the pills while held.
    public static var refreshSpinnerTopPadding: CGFloat {
        let spinner = SplickSpinner.Size.medium.dimension
        let gapStart = FeedSegmentChromeMetrics.overlappingNavigationInset
        let gapEnd = underChromeTopGap + refreshHeldPullDistance
        return gapStart + max(0, gapEnd - gapStart - spinner) / 2
    }

    public static var refreshHeldPullDistance: CGFloat {
        if #available(iOS 26.0, *) { 22 } else { 15 }
    }

    public static var minimumTopGap: CGFloat { underChromeTopGap }
    public static var defaultScrollTopMargin: CGFloat { underChromeTopGap }

    public static func initialTopMargin(for style: SplickSegmentPagerTopInsetStyle) -> CGFloat {
        switch style {
        case .tight:
            return tightTopGap
        case .underChrome:
            return underChromeTopGap
        }
    }
}

extension View {
    /// Keeps scroll content below the inline segment row; pairs with `SplickScrollTopFadeOverlay`.
    public func splickSegmentPagerScrollInsets(
        style: SplickSegmentPagerTopInsetStyle = .underChrome
    ) -> some View {
        modifier(SplickSegmentPagerScrollInsetsModifier(style: style))
    }

    /// Top inset for non-scroll pager pages (loading, empty, error, album chrome).
    public func splickSegmentPagerPageTopInset(
        isEnabled: Bool,
        style: SplickSegmentPagerTopInsetStyle = .underChrome
    ) -> some View {
        modifier(SplickSegmentPagerPageTopInsetModifier(isEnabled: isEnabled, style: style))
    }
}

private struct SplickSegmentPagerScrollInsetsModifier: ViewModifier {
    let style: SplickSegmentPagerTopInsetStyle

    private var topMargin: CGFloat {
        SplickSegmentPagerTopInsetMetrics.initialTopMargin(for: style)
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
    }
}

private struct SplickSegmentPagerPageTopInsetModifier: ViewModifier {
    let isEnabled: Bool
    let style: SplickSegmentPagerTopInsetStyle

    private var topPadding: CGFloat {
        SplickSegmentPagerTopInsetMetrics.initialTopMargin(for: style)
    }

    func body(content: Content) -> some View {
        content.padding(.top, isEnabled ? topPadding : 0)
    }
}
