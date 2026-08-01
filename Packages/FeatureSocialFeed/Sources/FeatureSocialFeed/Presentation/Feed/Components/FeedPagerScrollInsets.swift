import SwiftUI
import DesignSystem

enum FeedPagerTopInsetMetrics {
    /// Gap between the bottom of the inline segment row and the first feed card.
    static var minimumTopGap: CGFloat { SplickSegmentPagerTopInsetMetrics.minimumTopGap }
    static var defaultScrollTopMargin: CGFloat { SplickSegmentPagerTopInsetMetrics.defaultScrollTopMargin }

    static func resolvedTopMargin(for geometry: GeometryProxy) -> CGFloat {
        SplickSegmentPagerTopInsetMetrics.resolvedTopMargin(for: geometry)
    }
}

extension View {
    /// Keeps scroll content below the inline Chuỗi/Tin/Album segment row.
    func feedPagerScrollInsets() -> some View {
        splickSegmentPagerScrollInsets()
    }

    /// Top inset for non-scroll pager pages (loading, empty, error).
    func feedPagerPageTopInset(isEnabled: Bool) -> some View {
        splickSegmentPagerPageTopInset(isEnabled: isEnabled)
    }
}
