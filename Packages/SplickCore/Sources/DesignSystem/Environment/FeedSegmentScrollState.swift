import SwiftUI

// MARK: - Chrome metrics

public enum FeedSegmentChromeMetrics {
    public static let navigationBarHeight: CGFloat = 44
    /// Capsule row: 28pt buttons + 8pt vertical padding.
    public static let segmentRowHeight: CGFloat = 36
}

// MARK: - Scroll-driven collapse

@MainActor
public final class FeedSegmentScrollState: ObservableObject {
    /// 0 = pill tabs visible below nav bar; 1 = pills hidden, active label centered under notch.
    @Published public private(set) var collapseProgress: CGFloat = 0

    public var isExpanded: Bool { collapseProgress < 0.5 }

    private var lastOffset: CGFloat = 0
    private var offsetNormalizer = ScrollChromeOffsetNormalizer()
    private let showAtTopThreshold: CGFloat = 24
    private let collapseDistance: CGFloat = 72

    public init() {}

    public func updateScrollOffset(_ rawOffset: CGFloat) {
        let offset = offsetNormalizer.normalize(rawOffset)

        if offset <= showAtTopThreshold {
            setCollapseProgress(0)
            lastOffset = offset
            return
        }

        let delta = offset - lastOffset
        if abs(delta) > 0.5 {
            let next = min(1, max(0, collapseProgress + delta / collapseDistance))
            setCollapseProgress(next)
        }
        lastOffset = offset
    }

    public func snapCollapseProgress() {
        let target: CGFloat = collapseProgress >= 0.5 ? 1 : 0
        setCollapseProgress(target, animated: true)
    }

    public func reset() {
        lastOffset = 0
        offsetNormalizer.reset()
        setCollapseProgress(0, animated: false)
    }

    private func setCollapseProgress(_ value: CGFloat, animated: Bool = false) {
        let clamped = min(1, max(0, value))
        guard abs(collapseProgress - clamped) > 0.001 else { return }
        if animated {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                collapseProgress = clamped
            }
        } else {
            collapseProgress = clamped
        }
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
                content
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    } action: { _, offset in
                        feedSegmentScrollState.updateScrollOffset(offset)
                    }
                    .onScrollPhaseChange { oldPhase, newPhase in
                        if oldPhase == .interacting, newPhase != .interacting {
                            feedSegmentScrollState.snapCollapseProgress()
                        }
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
