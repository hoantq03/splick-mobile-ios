import SwiftUI
import UIKit
import DesignSystem

enum FeedPagerTopInsetMetrics {
    /// Gap between the bottom of the inline segment row and the first feed card.
    static var minimumTopGap: CGFloat { SplickSegmentPagerTopInsetMetrics.minimumTopGap }
    static var defaultScrollTopMargin: CGFloat { SplickSegmentPagerTopInsetMetrics.defaultScrollTopMargin }

    /// Bottom of the feed nav (pills live in the inline toolbar, not a second row).
    static var refreshChromeTopInset: CGFloat {
        FeedSegmentChromeMetrics.overlappingNavigationInset
    }

    /// Extra list translation while the PTR spinner is held after release.
    static var refreshHeldPullDistance: CGFloat {
        SplickSegmentPagerTopInsetMetrics.refreshHeldPullDistance
    }
}

extension View {
    /// Keeps scroll content below the inline Chuỗi/Tin/Album segment row.
    func feedPagerScrollInsets(
        style: SplickSegmentPagerTopInsetStyle = .underChrome
    ) -> some View {
        splickSegmentPagerScrollInsets(style: style)
    }

    /// Top inset for non-scroll pager pages (loading, empty, error).
    func feedPagerPageTopInset(
        isEnabled: Bool,
        style: SplickSegmentPagerTopInsetStyle = .underChrome
    ) -> some View {
        splickSegmentPagerPageTopInset(isEnabled: isEnabled, style: style)
    }
}
