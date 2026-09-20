import SwiftUI
import Combine

public enum SplickZoomPopChrome {
    /// Posted when interactive zoom-pop starts settling so tab/nav chrome can
    /// render under the flying card instead of hitching after it lands.
    public static let revealNotification = Notification.Name("splick.zoomPop.revealChrome")

    public static func reveal() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: revealNotification, object: nil)
        }
    }
}

public enum SplickTabBarMetrics {
    /// Space reserved above the floating tab bar so bottom controls stay tappable.
    public static let floatingClearance: CGFloat = 88
    /// Bottom inset when the tab bar is hidden (e.g. post detail).
    public static let hiddenClearance: CGFloat = 16
    /// Scroll offset (pt) at or below which the tab bar is always shown.
    public static let showNearTopThreshold: CGFloat = 64
    /// Tighter threshold for same-tab tap: scroll-to-top vs pull-to-refresh.
    public static let sameTabAtTopThreshold: CGFloat = 16

    public static let barHeight: CGFloat = 56
    public static let barBottomPadding: CGFloat = 4
    public static let cameraSizeIOS26: CGFloat = 63
    public static let cameraSizeLegacy: CGFloat = 72

    public static var cameraSize: CGFloat {
        if #available(iOS 26.0, *) { cameraSizeIOS26 } else { cameraSizeLegacy }
    }

    /// Distance from the tab-bar content’s bottom edge to the camera circle’s bottom edge.
    public static var cameraButtonBottomInset: CGFloat {
        barBottomPadding - max(cameraSize - barHeight, 0) / 2
    }

    /// Height of the tab bar stack inside `floatingClearance` (bar + bottom padding).
    public static var tabBarContentHeight: CGFloat {
        barHeight + barBottomPadding
    }

    /// `MainTabBarChrome` centers the tab bar in `floatingClearance`, leaving this
    /// gap under the bar. Reveal/shutter must include it or close snaps ~14pt.
    public static var tabBarClearanceBottomGap: CGFloat {
        max(floatingClearance - tabBarContentHeight, 0) / 2
    }

    /// Screen-bottom inset for the water origin and in-camera shutter at progress 0.
    /// Matches the centered tab camera — not raw `cameraButtonBottomInset` alone.
    public static var cameraRevealBottomInset: CGFloat {
        cameraButtonBottomInset + tabBarClearanceBottomGap
    }
}

public enum TabBarChromeMotion {
    /// Match feed segment / main-tab pager settle.
    public static let slide = Animation.easeOut(duration: 0.18)
    public static let show = Animation.easeOut(duration: 0.16)
}

@MainActor
public final class TabBarScrollState: ObservableObject {
    @Published public private(set) var isVisible = true
    /// When true (e.g. post detail), no extra bottom inset — composer can sit on the screen edge.
    @Published public private(set) var suppressesBottomInset = false
    /// Scroll hide uses a slide; navigation hide is instant so the bar never covers a docked composer.
    @Published public private(set) var animatesVisibility = true

    /// Fires when the user taps the tab button while already on that tab.
    public let sameTabTapSubject = PassthroughSubject<Void, Never>()

    private var lastOffset: CGFloat = 0
    /// Distance scrolled from the list's resting top (baseline-normalized).
    private var lastDistanceFromTop: CGFloat = 0
    private var offsetNormalizer = ScrollChromeOffsetNormalizer()
    private var distanceNormalizer = ScrollChromeOffsetNormalizer()
    private var suppressUpdatesUntil: Date = .distantPast
    private let hideThreshold: CGFloat = 8
    private let showAtTopThreshold: CGFloat = SplickTabBarMetrics.showNearTopThreshold
    /// Wait until past feed-segment collapse before hiding the tab bar so both
    /// chrome changes don't compete on the first leave-from-top frames.
    private let minDistanceBeforeHide: CGFloat = 52
    private let visibilityChangeCooldown: TimeInterval = 0.35

    /// Raw `contentOffset.y + contentInsets.top` from the active list.
    private var lastRawOffset: CGFloat = 0

    /// Custom PTR spinner is showing (pull or loading). Used to hide top fade overlays.
    @Published public private(set) var refreshIndicatorVisible = false

    /// True when the list is at (or very near) the top — used for same-tab tap refresh vs scroll-to-top.
    public var isAtTop: Bool {
        lastDistanceFromTop <= SplickTabBarMetrics.sameTabAtTopThreshold
            || lastRawOffset <= SplickTabBarMetrics.sameTabAtTopThreshold
    }

    public init() {}

    public func setRefreshIndicatorVisible(_ visible: Bool) {
        guard refreshIndicatorVisible != visible else { return }
        refreshIndicatorVisible = visible
    }

    /// Call when the user taps the active tab again — subscribers scroll to top or trigger refresh.
    public func handleSameTabTap() {
        sameTabTapSubject.send()
    }

    public func updateScrollOffset(_ rawOffset: CGFloat) {
        if Thread.isMainThread {
            applyScrollOffset(rawOffset)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.applyScrollOffset(rawOffset)
            }
        }
    }

    private func applyScrollOffset(_ rawOffset: CGFloat) {
        lastRawOffset = rawOffset
        // Normalize against resting baseline so contentMargins / inset don't look like "scrolled".
        lastDistanceFromTop = distanceNormalizer.normalize(rawOffset)

        // Use raw geometry for "at top" so a drifted baseline / hide-cooldown
        // can never leave the tab bar stuck hidden after returning near the top.
        if lastDistanceFromTop <= showAtTopThreshold || rawOffset <= showAtTopThreshold {
            revealAtTop(rawOffset: rawOffset)
            return
        }

        let offset = offsetNormalizer.normalize(rawOffset)

        guard Date() >= suppressUpdatesUntil else {
            // Keep tracking while suppressed so the next delta is not a jump.
            lastOffset = offset
            return
        }

        let delta = offset - lastOffset
        guard abs(delta) > hideThreshold else { return }

        if delta > hideThreshold, lastDistanceFromTop >= minDistanceBeforeHide {
            setVisible(false)
        } else if delta < -hideThreshold {
            setVisible(true)
        }
        lastOffset = offset
    }

    public func reset() {
        DispatchQueue.main.async { [weak self] in
            self?.resetNow()
        }
    }

    private func resetNow() {
        lastOffset = 0
        lastDistanceFromTop = 0
        lastRawOffset = 0
        offsetNormalizer.reset()
        distanceNormalizer.reset()
        if refreshIndicatorVisible {
            refreshIndicatorVisible = false
        }
        if suppressesBottomInset {
            suppressesBottomInset = false
        }
        if !animatesVisibility {
            animatesVisibility = true
        }
        setVisibleImmediate(true, applyCooldown: false)
    }

    public func show(animated: Bool = true) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.suppressesBottomInset {
                self.suppressesBottomInset = false
            }
            if self.animatesVisibility != animated {
                self.animatesVisibility = animated
            }
            self.setVisibleImmediate(true, applyCooldown: false)
        }
    }

    /// Hides the tab bar. Set `flushToBottom` on detail screens so bottom inset becomes zero.
    /// Navigation hides (`flushToBottom: true`) skip the slide so the bar is gone before the composer docks.
    public func hide(flushToBottom: Bool = false) {
        let animates = !flushToBottom
        if animatesVisibility != animates {
            animatesVisibility = animates
        }
        if suppressesBottomInset != flushToBottom {
            suppressesBottomInset = flushToBottom
        }
        setVisibleImmediate(false, applyCooldown: true)
    }

    private func revealAtTop(rawOffset: CGFloat) {
        distanceNormalizer.reset()
        lastDistanceFromTop = distanceNormalizer.normalize(rawOffset)
        offsetNormalizer.reset()
        lastOffset = offsetNormalizer.normalize(rawOffset)
        // Never leave the bar hidden near the top — bypass hide cooldown.
        setVisibleImmediate(true, applyCooldown: false)
    }

    private func setVisibleImmediate(_ visible: Bool, applyCooldown: Bool = true) {
        guard isVisible != visible else { return }
        isVisible = visible
        if applyCooldown {
            suppressUpdatesUntil = Date().addingTimeInterval(visibilityChangeCooldown)
        } else if visible {
            suppressUpdatesUntil = .distantPast
        }
    }

    private func setVisible(_ visible: Bool) {
        guard isVisible != visible else { return }
        animatesVisibility = true
        setVisibleImmediate(visible, applyCooldown: !visible)
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
                    // Always deliver near-top samples so the bar can reappear even on tiny settle deltas.
                    let nearTop = offset <= SplickTabBarMetrics.showNearTopThreshold
                    guard nearTop || abs(previous - offset) > 1 else { return }
                    tabBarScrollState.updateScrollOffset(offset)
                }
            } else {
                content.scrollChromeUIKitOffsetTracking(
                    isEnabled: scrollChromeTrackingEnabled && !pullToRefreshActive && !notificationsPresented
                ) { offset in
                    tabBarScrollState.updateScrollOffset(offset)
                }
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
