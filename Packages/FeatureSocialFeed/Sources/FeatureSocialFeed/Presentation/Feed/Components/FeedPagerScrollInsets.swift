import SwiftUI
import UIKit
import DesignSystem

enum FeedPagerTopInsetMetrics {
    /// Gap between the bottom of the inline segment row and the first feed card.
    static var minimumTopGap: CGFloat { SplickSegmentPagerTopInsetMetrics.minimumTopGap }
    static var defaultScrollTopMargin: CGFloat { SplickSegmentPagerTopInsetMetrics.defaultScrollTopMargin }

    static func resolvedTopMargin(for geometry: GeometryProxy) -> CGFloat {
        SplickSegmentPagerTopInsetMetrics.resolvedTopMargin(for: geometry, style: .underChrome)
    }

    /// Distance from the pager's top edge to just below the Chuỗi/Tin/Album pills.
    static var refreshChromeTopInset: CGFloat {
        let safeTop = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top) ?? 59
        return safeTop
            + FeedSegmentChromeMetrics.navigationBarHeight
            + FeedSegmentChromeMetrics.segmentRowHeight
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
