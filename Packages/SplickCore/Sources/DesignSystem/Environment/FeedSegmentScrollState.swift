import SwiftUI

@MainActor
public final class FeedSegmentScrollState: ObservableObject {
    @Published public private(set) var isExpanded = true

    private var lastOffset: CGFloat = 0
    private let hideThreshold: CGFloat = 8
    private let showAtTopThreshold: CGFloat = 24

    public init() {}

    public func updateScrollOffset(_ offset: CGFloat) {
        if offset <= showAtTopThreshold {
            setExpanded(true)
            lastOffset = offset
            return
        }

        let delta = offset - lastOffset
        if delta > hideThreshold {
            setExpanded(false)
        } else if delta < -hideThreshold {
            setExpanded(true)
        }
        lastOffset = offset
    }

    public func reset() {
        lastOffset = 0
        setExpanded(true)
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
    }
}

private struct FeedSegmentScrollStateKey: EnvironmentKey {
    static let defaultValue: FeedSegmentScrollState? = nil
}

extension EnvironmentValues {
    public var feedSegmentScrollState: FeedSegmentScrollState? {
        get { self[FeedSegmentScrollStateKey.self] }
        set { self[FeedSegmentScrollStateKey.self] = newValue }
    }
}

public struct FeedSegmentHideOnScrollModifier: ViewModifier {
    @Environment(\.feedSegmentScrollState) private var feedSegmentScrollState

    public init() {}

    public func body(content: Content) -> some View {
        if let feedSegmentScrollState {
            if #available(iOS 18.0, *) {
                content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, offset in
                    feedSegmentScrollState.updateScrollOffset(offset)
                }
            } else {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    public func feedSegmentHideOnScroll() -> some View {
        modifier(FeedSegmentHideOnScrollModifier())
    }
}
