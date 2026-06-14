import SwiftUI

/// Converts raw `onScrollGeometryChange` offsets into distance scrolled from the initial rest position.
struct ScrollChromeOffsetNormalizer {
    private var baseline: CGFloat?

    mutating func reset() {
        baseline = nil
    }

    mutating func normalize(_ rawOffset: CGFloat) -> CGFloat {
        if baseline == nil {
            baseline = rawOffset
        }
        return max(0, rawOffset - (baseline ?? rawOffset))
    }
}

private struct ScrollContentOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Zero-height sentinel placed at the top of `ScrollView` content.
/// Reports vertical scroll offset on iOS 16–17 where `onScrollGeometryChange` is unavailable.
struct ScrollContentOffsetTracker: View {
    let coordinateSpaceName: String
    let onOffsetChange: (CGFloat) -> Void

    @State private var baselineMinY: CGFloat?

    var body: some View {
        Color.clear
            .frame(height: 0)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollContentOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named(coordinateSpaceName)).minY
                    )
                }
            )
            .onPreferenceChange(ScrollContentOffsetPreferenceKey.self) { minY in
                if baselineMinY == nil {
                    baselineMinY = minY
                }
                let offset = max(0, (baselineMinY ?? minY) - minY)
                onOffsetChange(offset)
            }
    }

    func resetBaseline() {
        baselineMinY = nil
    }

}


/// Wraps scroll content with a legacy offset tracker for tab bar + feed segment chrome.
struct ScrollChromeOffsetTrackingModifier: ViewModifier {
    let coordinateSpace: String

    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.feedSegmentScrollState) private var feedSegmentScrollState

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
        } else {
            VStack(spacing: 0) {
                ScrollContentOffsetTracker(coordinateSpaceName: coordinateSpace) { offset in
                    tabBarScrollState?.updateScrollOffset(offset)
                    feedSegmentScrollState?.updateScrollOffset(offset)
                }
                content
            }
        }
    }
}

extension View {
    /// iOS 16–17 fallback for `.tabBarHideOnScroll()` / `.feedSegmentHideOnScroll()`.
    /// Apply to the root content inside a named `ScrollView` coordinate space.
    public func scrollChromeOffsetTracking(coordinateSpace: String) -> some View {
        modifier(ScrollChromeOffsetTrackingModifier(coordinateSpace: coordinateSpace))
    }
}
