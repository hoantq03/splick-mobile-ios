import SwiftUI
import Combine

public enum SplickTabBarMetrics {
    /// Space reserved above the floating tab bar so bottom controls stay tappable.
    public static let floatingClearance: CGFloat = 88
    /// Bottom inset when the tab bar is hidden (e.g. post detail).
    public static let hiddenClearance: CGFloat = 16
}

public enum TabBarChromeMotion {
    /// Smooth vertical slide — no spring overshoot.
    public static let slide = Animation.easeInOut(duration: 0.30)
    public static let show = Animation.easeInOut(duration: 0.26)
}

@MainActor
public final class TabBarScrollState: ObservableObject {
    @Published public private(set) var isVisible = true
    /// When true (e.g. post detail), no extra bottom inset — composer can sit on the screen edge.
    @Published public private(set) var suppressesBottomInset = false

    /// Fires when the user taps the tab button while already on that tab.
    public let sameTabTapSubject = PassthroughSubject<Void, Never>()

    private var lastOffset: CGFloat = 0
    private var offsetNormalizer = ScrollChromeOffsetNormalizer()
    private var suppressUpdatesUntil: Date = .distantPast
    private let hideThreshold: CGFloat = 8
    private let showAtTopThreshold: CGFloat = 24
    private let visibilityChangeCooldown: TimeInterval = 0.35

    /// True when the tracked scroll position is at (or near) the top.
    public var isAtTop: Bool { lastOffset <= showAtTopThreshold }

    public init() {}

    /// Call when the user taps the active tab again — subscribers scroll to top or trigger refresh.
    public func handleSameTabTap() {
        sameTabTapSubject.send()
    }

    public func updateScrollOffset(_ rawOffset: CGFloat) {
        guard Date() >= suppressUpdatesUntil else { return }

        let offset = offsetNormalizer.normalize(rawOffset)

        if offset <= showAtTopThreshold {
            setVisible(true)
            lastOffset = offset
            return
        }

        let delta = offset - lastOffset
        if delta > hideThreshold {
            setVisible(false)
        } else if delta < -hideThreshold {
            setVisible(true)
        }
        lastOffset = offset
    }

    public func reset() {
        Task { @MainActor in
            lastOffset = 0
            offsetNormalizer.reset()
            suppressesBottomInset = false
            setVisibleImmediate(true)
        }
    }

    public func show() {
        Task { @MainActor in
            suppressesBottomInset = false
            setVisibleImmediate(true)
        }
    }

    /// Hides the tab bar. Set `flushToBottom` on detail screens so bottom inset becomes zero.
    public func hide(flushToBottom: Bool = false) {
        Task { @MainActor in
            suppressesBottomInset = flushToBottom
            setVisibleImmediate(false)
        }
    }

    private func setVisibleImmediate(_ visible: Bool) {
        guard isVisible != visible else { return }
        isVisible = visible
        suppressUpdatesUntil = Date().addingTimeInterval(visibilityChangeCooldown)
    }

    private func setVisible(_ visible: Bool) {
        guard isVisible != visible else { return }
        Task { @MainActor in
            setVisibleImmediate(visible)
        }
    }
}

private struct TabBarScrollStateKey: EnvironmentKey {
    static let defaultValue: TabBarScrollState? = nil
}

extension EnvironmentValues {
    public var tabBarScrollState: TabBarScrollState? {
        get { self[TabBarScrollStateKey.self] }
        set { self[TabBarScrollStateKey.self] = newValue }
    }
}

public struct TabBarHideOnScrollModifier: ViewModifier {
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.scrollChromeTrackingEnabled) private var scrollChromeTrackingEnabled
    @Environment(\.pullToRefreshActive) private var pullToRefreshActive
    @Environment(\.notificationsPresented) private var notificationsPresented

    public init() {}

    public func body(content: Content) -> some View {
        if let tabBarScrollState {
            if #available(iOS 18.0, *) {
                content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { previous, offset in
                    guard scrollChromeTrackingEnabled,
                          !pullToRefreshActive,
                          !notificationsPresented else { return }
                    guard abs(previous - offset) > 0.25 else { return }
                    tabBarScrollState.updateScrollOffset(offset)
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
    public func tabBarHideOnScroll() -> some View {
        modifier(TabBarHideOnScrollModifier())
    }

    /// Reserves space above the floating tab bar so scroll content is not clipped underneath it.
    public func tabBarContentPadding(isEnabled: Bool = true) -> some View {
        modifier(TabBarContentPaddingModifier(isEnabled: isEnabled))
    }
}

public struct TabBarContentPaddingModifier: ViewModifier {
    private let isEnabled: Bool
    @Environment(\.tabBarScrollState) private var tabBarScrollState

    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    private var bottomInset: CGFloat {
        guard isEnabled else { return 0 }
        guard let tabBarScrollState else { return SplickTabBarMetrics.floatingClearance }
        if tabBarScrollState.suppressesBottomInset { return 0 }
        // Keep inset stable while the tab bar hides/shows to avoid scroll feedback loops.
        return SplickTabBarMetrics.floatingClearance
    }

    public func body(content: Content) -> some View {
        content
            .modifier(TabBarBottomInsetModifier(inset: bottomInset))
            .animation(TabBarChromeMotion.slide, value: bottomInsetAnimationToken)
    }

    private var bottomInsetAnimationToken: String {
        guard let tabBarScrollState else { return "default" }
        return "\(tabBarScrollState.suppressesBottomInset)-\(isEnabled)"
    }
}

private struct TabBarBottomInsetModifier: ViewModifier {
    let inset: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.safeAreaPadding(.bottom, inset)
        } else {
            content.padding(.bottom, inset)
        }
    }
}
