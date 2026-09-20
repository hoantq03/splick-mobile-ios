import SwiftUI
import Combine
import UIKit
import Localization
import Common

// MARK: - Environment

public struct PullToRefreshActiveKey: EnvironmentKey {
    public static let defaultValue = false
}

extension EnvironmentValues {
    public var pullToRefreshActive: Bool {
        get { self[PullToRefreshActiveKey.self] }
        set { self[PullToRefreshActiveKey.self] = newValue }
    }
}

/// Bubbles pull-to-refresh state up to ancestor views (e.g. chrome outside the `ScrollView`).
public struct PullToRefreshActivePreferenceKey: PreferenceKey {
    public static let defaultValue = false

    public static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

// MARK: - Modifier

public extension View {
    /// Native pull-to-refresh via SwiftUI `.refreshable`, with optional programmatic refresh (tab re-tap).
    /// Programmatic refresh drives the same `UIRefreshControl` spinner as a manual pull.
    func splickNativeRefreshable(
        controller: SplickRefreshController? = nil,
        chromeTopInset: CGFloat = 0,
        action: @escaping () async -> Void
    ) -> some View {
        modifier(
            SplickNativeRefreshableModifier(
                controller: controller,
                chromeTopInset: chromeTopInset,
                action: action
            )
        )
    }
}

private struct SplickNativeRefreshableModifier: ViewModifier {
    let controller: SplickRefreshController?
    let chromeTopInset: CGFloat
    let action: () async -> Void

    func body(content: Content) -> some View {
        if let controller {
            content.modifier(
                SplickNativeRefreshableWithController(
                    controller: controller,
                    chromeTopInset: chromeTopInset,
                    action: action
                )
            )
        } else {
            content.refreshable { await action() }
        }
    }
}

private struct SplickNativeRefreshableWithController: ViewModifier {
    @ObservedObject var controller: SplickRefreshController
    let chromeTopInset: CGFloat
    let action: () async -> Void

    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @StateObject private var refreshHost = SplickScrollRefreshHost()
    @State private var isRefreshing = false
    @State private var refreshTask: Task<Void, Never>?
    /// Only used when the underlying scroll view has no `UIRefreshControl` yet.
    @State private var showsFallbackHeader = false
    @State private var handledRequestID = 0
    /// SwiftUI bounce for lists that sit under overlapping chrome (feed pager).
    @State private var chromeContentBounce: CGFloat = 0
    @State private var frozenPullRotation: Double = 0

    /// Content shift while spinner spins. Chrome tabs need less because the spinner
    /// already sits below the nav bar; non-chrome tabs need more visible pull space.
    private var heldRefreshPull: CGFloat { chromeTopInset > 0 ? 15 : 40 }

    private var trackingRotation: Double {
        Double(visiblePull / SplickScrollRefreshHost.fullRotationPull) * 360
    }

    private var visiblePull: CGFloat {
        if chromeContentBounce > 0 {
            return chromeContentBounce
        }
        if isRefreshing || showsFallbackHeader {
            return max(refreshHost.pullDistance, heldRefreshPull)
        }
        return refreshHost.pullDistance
    }

    private var isIndicatorVisible: Bool {
        isRefreshing || showsFallbackHeader || visiblePull > 4
    }

    private var spinnerTopPadding: CGFloat {
        if chromeTopInset > 0 {
            return chromeTopInset + 6
        }
        // Hosted feed/expense lists pass an overlapping-nav inset. Overlay
        // sheets (notifications) sit below their own header — pin the spinner
        // to the scroll top so it is visible in the pull gap.
        return 8
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            refreshableScrollContent(content)

            let isLoading = isRefreshing || showsFallbackHeader
            SplickSpinner(
                size: .medium,
                rotationDegrees: isLoading ? frozenPullRotation : trackingRotation,
                isSpinning: isLoading
            )
            .frame(maxWidth: .infinity)
            .padding(.top, spinnerTopPadding)
            .opacity(isIndicatorVisible ? 1 : 0)
            .accessibilityHidden(!isIndicatorVisible)
            .allowsHitTesting(false)
            .transaction { $0.animation = nil }
        }
            .environment(\.pullToRefreshActive, isIndicatorVisible)
            .preference(key: PullToRefreshActivePreferenceKey.self, value: isIndicatorVisible)
            .onReceive(controller.$requestID) { requestID in
                guard requestID > handledRequestID else { return }
                handledRequestID = requestID
                Task { await runProgrammaticRefresh() }
            }
            .onChange(of: isIndicatorVisible) { visible in
                tabBarScrollState?.setRefreshIndicatorVisible(visible)
            }
            .onAppear {
                refreshHost.usesChromePullVisual = true
                refreshHost.applyClearSystemTint()
                refreshHost.onPullCommit = { [self] in
                    // Called from UIKit gesture handler — safe to start task.
                    frozenPullRotation = trackingRotation
                    chromeContentBounce = heldRefreshPull
                    // Spring from the current (possibly overscrolled) position
                    // down to exactly the spinner resting height.
                    refreshHost.animateChromeTransform(
                        to: heldRefreshPull,
                        duration: 0.32,
                        damping: 0.78
                    )
                    Task { await runRefresh() }
                }
            }
    }

    /// Custom pan + overlay spinner. System `.refreshable` adds inset at 100% and desyncs tabs.
    @ViewBuilder
    private func refreshableScrollContent(_ content: Content) -> some View {
        content
            .background {
                SplickScrollViewRefreshAnchor(host: refreshHost)
            }
    }

    // MARK: - Refresh lifecycle

    @MainActor
    private func runRefresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        await SplickViewUpdate.hop()
        isRefreshing = true
        let task = Task { @MainActor in
            await action()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
        await SplickViewUpdate.hop()
        settle()
    }

    @MainActor
    private func runProgrammaticRefresh() async {
        guard refreshTask == nil, !isRefreshing else { return }
        await SplickViewUpdate.hop()
        isRefreshing = true
        tabBarScrollState?.setRefreshIndicatorVisible(true)
        await refreshHost.ensureAttached()
        refreshHost.prepareProgrammaticCommit()
        frozenPullRotation = 0
        await playChromeContentBounce()
        let task = Task { @MainActor in
            await action()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
        refreshHost.endRefreshing()
        await SplickViewUpdate.hop()
        settle()
    }

    /// Resets all PTR state and animates the UIKit scroll view transform back to rest.
    /// Called exactly once after the action completes — never from `onChange`.
    @MainActor
    private func settle() {
        showsFallbackHeader = false
        isRefreshing = false
        chromeContentBounce = 0
        refreshHost.resetGesturePeak()
        refreshHost.animateChromeTransformToRest(duration: 0.22)
    }

    @MainActor
    private func playChromeContentBounce() async {
        let hold = heldRefreshPull
        let overshoot = hold + 20
        refreshHost.applyChromeTransform(overshoot)
        chromeContentBounce = overshoot
        try? await Task.sleep(nanoseconds: UInt64(SplickProgrammaticRefreshMotion.pullDuration * 1_000_000_000))
        refreshHost.animateChromeTransform(to: hold, duration: SplickProgrammaticRefreshMotion.bounceDuration, damping: SplickProgrammaticRefreshMotion.bounceDamping)
        chromeContentBounce = hold
        try? await Task.sleep(nanoseconds: 80_000_000)
    }
}

// MARK: - Native UIRefreshControl bridge

private enum SplickProgrammaticRefreshMotion {
    /// Extra pull past the resting refresh height, then spring back.
    static let overshoot: CGFloat = 44
    static let pullDuration: TimeInterval = 0.12
    static let bounceDuration: TimeInterval = 0.34
    static let bounceDamping: CGFloat = 0.55
    static let bounceVelocity: CGFloat = 1.1
}

/// Finds the underlying `UIScrollView` and drives its native refresh control.
@MainActor
public final class SplickScrollRefreshHost: NSObject, ObservableObject, UIGestureRecognizerDelegate {
    public weak var scrollView: UIScrollView?
    private weak var attachProbe: UIView?
    @Published public private(set) var pullDistance: CGFloat = 0
    public var pullRotationDegrees: Double {
        Double(pullDistance / Self.fullRotationPull) * 360
    }
    public private(set) var completedFullRotation = false
    var onPullCommit: (() -> Void)?
    /// Feed pager: translate the UIKit scroll view so SwiftUI chrome/spinner layout stays put.
    var usesChromePullVisual = false

    private var offsetObservation: NSKeyValueObservation?
    private var panRecognizer: UIPanGestureRecognizer?
    private var maxPullInGesture: CGFloat = 0
    private var wasDragging = false
    private var chromePulling = false
    private var didThresholdHaptic = false
    private var lastOverscrollHapticFinger: CGFloat = 0
    private let thresholdHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let overscrollHaptic = UIImpactFeedbackGenerator(style: .light)

    static let fullRotationPull = SplickSpinner.fullRotationPullDistance(for: .medium)
    /// Extra travel allowed after 100% rotation (resisted, not 1:1).
    private static let overscrollLimit: CGFloat = 34
    private static let overscrollHapticStep: CGFloat = 12

    public override init() {}

    public func applyClearSystemTint() {
        scrollView?.refreshControl?.tintColor = .clear
    }

    func applyChromeTransform(_ y: CGFloat) {
        guard usesChromePullVisual, let scrollView else { return }
        let translation = max(0, y)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        scrollView.transform = CGAffineTransform(translationX: 0, y: translation)
        CATransaction.commit()
        lockChromeOffsetToRest()
    }

    /// Animated retraction used when refresh finishes.
    func animateChromeTransformToRest(duration: TimeInterval = 0.22) {
        guard usesChromePullVisual, let scrollView else { return }
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            scrollView.transform = .identity
        }
    }

    /// Animated transition to a specific pull height (programmatic bounce).
    func animateChromeTransform(to y: CGFloat, duration: TimeInterval, damping: CGFloat) {
        guard usesChromePullVisual, let scrollView else { return }
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: 0, options: [.beginFromCurrentState]) {
            scrollView.transform = CGAffineTransform(translationX: 0, y: max(0, y))
        }
    }

    private func lockChromeOffsetToRest() {
        guard usesChromePullVisual, let scrollView else { return }
        let restY = -scrollView.adjustedContentInset.top
        if abs(scrollView.contentOffset.y - restY) > 0.5 {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: restY)
            CATransaction.commit()
        }
    }

    public func prepareProgrammaticCommit() {
        completedFullRotation = true
    }

    public func shouldCommitRefresh() -> Bool {
        completedFullRotation || maxPullInGesture >= Self.fullRotationPull * 0.98
    }

    public func resetGesturePeak() {
        maxPullInGesture = 0
        completedFullRotation = false
        didThresholdHaptic = false
        lastOverscrollHapticFinger = 0
        if usesChromePullVisual {
            SplickViewUpdate.after { [weak self] in
                self?.pullDistance = 0
            }
        }
    }

    /// Sit just under overlapping nav chrome; do not follow pull distance (that jumps at 100%).
    public func spinnerOverlayTopPadding() -> CGFloat {
        guard let scrollView else { return 8 }
        let inset = max(0, scrollView.adjustedContentInset.top)
        let originY = scrollView.convert(CGPoint.zero, to: nil).y
        let safeTop = scrollView.window?.safeAreaInsets.top ?? 59
        let overlappingNav = max(0, (safeTop + FeedSegmentChromeMetrics.navigationBarHeight) - originY)
        return max(inset, overlappingNav) + 6
    }

    public func currentPullDistance() -> CGFloat {
        guard let scrollView else { return 0 }
        return max(0, -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top))
    }

    private func isScrollViewAtTop() -> Bool {
        guard let scrollView else { return true }
        let restY = -scrollView.adjustedContentInset.top
        // Overlay/safe-area lists often sit a few points below rest until the
        // first scroll. Match the bootstrap snap window so chrome pull can start.
        return scrollView.contentOffset.y <= restY + 64
    }

    private func prepareScrollViewForPull(_ scrollView: UIScrollView) {
        scrollView.alwaysBounceVertical = true
        scrollView.bounces = true
        let restY = -scrollView.adjustedContentInset.top
        if scrollView.contentOffset.y > restY, scrollView.contentOffset.y < restY + 64 {
            scrollView.setContentOffset(
                CGPoint(x: scrollView.contentOffset.x, y: restY),
                animated: false
            )
        }
    }

    /// Shows the same spinner as a manual pull-to-refresh, with a fast overshoot + bounce-back.
    @discardableResult
    public func beginRefreshing() async -> Bool {
        await resolveRefreshableScrollView(retryIfMissingControl: true)

        guard let scrollView else { return false }
        if scrollView.refreshControl == nil {
            let control = UIRefreshControl()
            control.tintColor = .clear
            scrollView.refreshControl = control
        }
        guard let refreshControl = scrollView.refreshControl else { return false }
        refreshControl.tintColor = .clear
        guard !refreshControl.isRefreshing else { return true }

        scrollView.alwaysBounceVertical = true
        scrollView.bounces = true

        let topInset = scrollView.adjustedContentInset.top
        let controlHeight = max(refreshControl.bounds.height, 60)
        let settledOffset = CGPoint(x: 0, y: -(topInset + controlHeight))
        let overshootOffset = CGPoint(
            x: 0,
            y: settledOffset.y - SplickProgrammaticRefreshMotion.overshoot
        )

        let previousBounces = scrollView.bounces
        scrollView.bounces = false
        defer { scrollView.bounces = previousBounces }

        // 1) Fast deep pull past the refresh threshold.
        await Self.animateContentOffset(
            scrollView,
            to: overshootOffset,
            duration: SplickProgrammaticRefreshMotion.pullDuration,
            damping: 1.0,
            velocity: 0
        )

        // 2) Engage native spinner while still overshot, then spring back.
        refreshControl.beginRefreshing()
        refreshControl.tintColor = .clear
        // `beginRefreshing` grows top inset — recompute resting offset from the new inset.
        let settledAfterRefresh = CGPoint(x: 0, y: -scrollView.adjustedContentInset.top)
        if scrollView.contentOffset.y > overshootOffset.y {
            scrollView.contentOffset = overshootOffset
        }

        await Self.animateContentOffset(
            scrollView,
            to: settledAfterRefresh,
            duration: SplickProgrammaticRefreshMotion.bounceDuration,
            damping: SplickProgrammaticRefreshMotion.bounceDamping,
            velocity: SplickProgrammaticRefreshMotion.bounceVelocity
        )

        return true
    }

    public func endRefreshing() {
        guard let refreshControl = scrollView?.refreshControl, refreshControl.isRefreshing else { return }
        refreshControl.endRefreshing()
    }

    private static func animateContentOffset(
        _ scrollView: UIScrollView,
        to offset: CGPoint,
        duration: TimeInterval,
        damping: CGFloat,
        velocity: CGFloat
    ) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UIView.animate(
                withDuration: duration,
                delay: 0,
                usingSpringWithDamping: damping,
                initialSpringVelocity: velocity,
                options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
            ) {
                scrollView.contentOffset = offset
            } completion: { _ in
                continuation.resume()
            }
        }
    }

    public func attach(from view: UIView) {
        attachProbe = view
        let resolved = findRefreshableScrollView(near: view)
        if let resolved {
            bind(to: resolved)
            applyClearSystemTint()
            return
        }
        if scrollView?.window == nil {
            unbindScrollView()
        }
    }

    /// Cold launch: the feed pager may not have resolved a UIScrollView until
    /// the first user pan. Retry from the last probe so tab-tap bounce can run.
    func ensureAttached() async {
        for _ in 0..<8 {
            if let attachProbe {
                attach(from: attachProbe)
            }
            if scrollView != nil { return }
            try? await Task.sleep(nanoseconds: 40_000_000)
        }
    }

    private func bind(to resolved: UIScrollView) {
        guard scrollView !== resolved else {
            installPullTrackingIfNeeded()
            return
        }
        unbindScrollView()
        scrollView = resolved
        installPullTrackingIfNeeded()
    }

    private func unbindScrollView() {
        offsetObservation?.invalidate()
        offsetObservation = nil
        if let panRecognizer, let scrollView {
            scrollView.removeGestureRecognizer(panRecognizer)
        }
        panRecognizer = nil
        scrollView?.transform = .identity
        scrollView = nil
        chromePulling = false
    }

    private func installPullTrackingIfNeeded() {
        guard let scrollView else { return }
        prepareScrollViewForPull(scrollView)
        if offsetObservation == nil {
            offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] sv, _ in
                guard let self else { return }
                // Skip KVO-driven updates while chrome pull is managed by the pan gesture.
                guard !self.chromePulling else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.handleContentOffsetChange()
                }
            }
        }
        if panRecognizer == nil {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePullPan(_:)))
            pan.delegate = self
            pan.cancelsTouchesInView = false
            pan.maximumNumberOfTouches = 1
            scrollView.addGestureRecognizer(pan)
            panRecognizer = pan
        }
    }

    @objc private func handlePullPan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            maxPullInGesture = 0
            completedFullRotation = false
            didThresholdHaptic = false
            lastOverscrollHapticFinger = 0
            wasDragging = true
            chromePulling = usesChromePullVisual && isScrollViewAtTop()
            thresholdHaptic.prepare()
            overscrollHaptic.prepare()
            if chromePulling {
                updateTrackedPull(
                    max(0, recognizer.translation(in: recognizer.view).y),
                    applyChromeResistance: true
                )
            } else {
                handleContentOffsetChange()
            }
        case .changed:
            let translationY = recognizer.translation(in: recognizer.view).y
            // Engage mid-gesture when the finger clearly pulls down from near top —
            // `.began` alone can miss if the scroll view isn't settled yet.
            if usesChromePullVisual, !chromePulling, translationY > 8, isScrollViewAtTop() {
                chromePulling = true
            }
            if chromePulling {
                // Small negative noise used to drop chrome pull and kill overscroll haptics.
                if translationY < -10 {
                    chromePulling = false
                    SplickViewUpdate.after { [weak self] in
                        self?.pullDistance = 0
                    }
                    applyChromeTransform(0)
                    handleContentOffsetChange()
                } else {
                    updateTrackedPull(max(0, translationY), applyChromeResistance: true)
                    lockChromeOffsetToRest()
                }
            } else {
                handleContentOffsetChange()
            }
        case .ended, .cancelled, .failed:
            if chromePulling {
                updateTrackedPull(
                    max(0, recognizer.translation(in: recognizer.view).y),
                    applyChromeResistance: true
                )
            } else {
                handleContentOffsetChange()
            }
            handleFingerRelease()
        default:
            break
        }
    }

    private func handleContentOffsetChange() {
        if usesChromePullVisual, chromePulling || (scrollView?.transform.ty ?? 0) > 0.5 {
            lockChromeOffsetToRest()
            return
        }
        updateTrackedPull(currentPullDistance(), applyChromeResistance: false)
    }

    /// 1:1 until a full spinner turn, then UIKit-style rubber-band and a hard cap.
    private func resistedPull(from finger: CGFloat) -> CGFloat {
        let threshold = Self.fullRotationPull
        let y = max(0, finger)
        guard y > threshold else { return y }
        let extra = y - threshold
        let dim = Self.overscrollLimit
        let rubber = (1 - 1 / (extra * 0.45 / dim + 1)) * dim
        return threshold + min(rubber, dim)
    }

    private func updateTrackedPull(_ finger: CGFloat, applyChromeResistance: Bool) {
        let raw = max(0, finger)
        let distance = applyChromeResistance ? resistedPull(from: raw) : raw
        if distance > 2 {
            maxPullInGesture = max(maxPullInGesture, distance)
        }
        emitPullHaptics(finger: raw, mapped: distance, repeatingOverscroll: applyChromeResistance)
        if applyChromeResistance {
            applyChromeTransform(distance)
        }
        if abs(pullDistance - distance) > 0.12 {
            let apply: () -> Void = { [weak self] in
                guard let self, abs(self.pullDistance - distance) > 0.12 else { return }
                self.pullDistance = distance
            }
            // Chrome pan runs on UIKit's gesture callback — publish immediately
            // so the overlay spinner tracks the finger. KVO can fire during a
            // SwiftUI render, so hop that path.
            if applyChromeResistance {
                apply()
            } else {
                SplickViewUpdate.after(apply)
            }
        }
    }

    private func emitPullHaptics(finger: CGFloat, mapped: CGFloat, repeatingOverscroll: Bool) {
        if !didThresholdHaptic, mapped >= Self.fullRotationPull * 0.98 {
            didThresholdHaptic = true
            lastOverscrollHapticFinger = finger
            thresholdHaptic.impactOccurred(intensity: 1)
            overscrollHaptic.prepare()
            return
        }
        // Keep step ticks after threshold for any active downward pull. Gating on
        // `repeatingOverscroll` alone dropped haptics when chromePulling flickered off.
        guard didThresholdHaptic,
              finger > lastOverscrollHapticFinger + Self.overscrollHapticStep else {
            return
        }
        // Prefer chrome-resistance pulls; still tick on rubber-band distance when the
        // finger keeps traveling past the threshold (mapped tracks offset pull).
        guard repeatingOverscroll || mapped >= Self.fullRotationPull else { return }
        lastOverscrollHapticFinger = finger
        overscrollHaptic.impactOccurred(intensity: 0.72)
        overscrollHaptic.prepare()
    }

    private func handleFingerRelease() {
        wasDragging = false
        chromePulling = false
        completedFullRotation = maxPullInGesture >= Self.fullRotationPull
        if completedFullRotation {
            onPullCommit?()
        } else {
            SplickViewUpdate.after { [weak self] in
                self?.pullDistance = 0
            }
            if usesChromePullVisual {
                animateChromeTransformToRest(duration: 0.18)
            }
        }
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    private func resolveRefreshableScrollView(retryIfMissingControl: Bool) async {
        if let current = scrollView {
            self.scrollView = findRefreshableScrollView(near: current) ?? current
        }
        guard retryIfMissingControl else { return }
        for _ in 0..<6 {
            if scrollView?.refreshControl != nil { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
            if let current = scrollView {
                self.scrollView = findRefreshableScrollView(near: current) ?? current
            }
        }
    }

    private func findRefreshableScrollView(near view: UIView) -> UIScrollView? {
        var nearestWithControl: UIScrollView?
        var nearestWithoutControl: UIScrollView?

        var ancestor: UIView? = view
        while let current = ancestor {
            if let scrollView = current as? UIScrollView,
               Self.isLikelyVerticalContentScrollView(scrollView) {
                if scrollView.refreshControl != nil {
                    nearestWithControl = scrollView
                    break
                }
                if nearestWithoutControl == nil {
                    nearestWithoutControl = scrollView
                }
            }
            ancestor = current.superview
        }

        if let nearestWithControl {
            return nearestWithControl
        }

        if let nearestWithoutControl {
            var innerWithControl: UIScrollView?
            Self.enumerateScrollViews(in: nearestWithoutControl) { scrollView in
                guard scrollView !== nearestWithoutControl else { return }
                guard Self.isLikelyVerticalContentScrollView(scrollView) else { return }
                if scrollView.refreshControl != nil, innerWithControl == nil {
                    innerWithControl = scrollView
                }
            }
            if let innerWithControl {
                return innerWithControl
            }
        }

        let searchRoot = enclosingPageHostingView(near: view) ?? view
        var preferred: UIScrollView?
        var fallback: UIScrollView?
        Self.enumerateScrollViews(in: searchRoot) { scrollView in
            guard Self.isLikelyVerticalContentScrollView(scrollView) else { return }
            if scrollView.refreshControl != nil {
                if preferred == nil || scrollView.bounds.height > preferred!.bounds.height {
                    preferred = scrollView
                }
            } else if fallback == nil || scrollView.bounds.height > fallback!.bounds.height {
                fallback = scrollView
            }
        }
        return preferred ?? nearestWithoutControl ?? fallback
    }

    private func enclosingPageHostingView(near view: UIView) -> UIView? {
        var responder: UIResponder? = view
        while let current = responder {
            if let viewController = current as? UIViewController {
                let typeName = NSStringFromClass(type(of: viewController))
                if typeName.contains("HostingController") {
                    return viewController.view
                }
            }
            responder = current.next
        }
        return nil
    }

    private static func enumerateScrollViews(in root: UIView, visit: (UIScrollView) -> Void) {
        if let scrollView = root as? UIScrollView {
            visit(scrollView)
        }
        for subview in root.subviews {
            enumerateScrollViews(in: subview, visit: visit)
        }
    }

    private static func isLikelyVerticalContentScrollView(_ scrollView: UIScrollView) -> Bool {
        let wide = scrollView.contentSize.width > scrollView.bounds.width * 1.2
        if scrollView.isPagingEnabled, wide { return false }
        if wide, scrollView.bounds.height > 0, scrollView.bounds.height < 120 {
            return false
        }
        return true
    }
}

/// Invisible anchor that resolves the nearest refreshable `UIScrollView`.
public struct SplickScrollViewRefreshAnchor: UIViewRepresentable {
    @ObservedObject var host: SplickScrollRefreshHost

    public init(host: SplickScrollRefreshHost) {
        self.host = host
    }

    public func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            host.attach(from: uiView)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            host.attach(from: uiView)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            host.attach(from: uiView)
        }
    }
}

/// Prepares the SwiftUI `ScrollView` so the first pull can trigger `.refreshable`.
/// Without this, UIKit often leaves `alwaysBounceVertical` off (or a nested media
/// pager eats the pan) until the user has scrolled once.
public struct SplickRefreshableScrollBootstrap: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> UIView {
        let view = BootstrapView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? BootstrapView)?.schedulePrepare()
    }

    private final class BootstrapView: UIView {
        private var scheduled = false

        func schedulePrepare() {
            guard !scheduled else {
                prepare()
                return
            }
            scheduled = true
            prepare()
            DispatchQueue.main.async { [weak self] in self?.prepare() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.prepare()
            }
        }

        private func prepare() {
            guard let scrollView = Self.findVerticalScrollView(near: self) else { return }
            scrollView.alwaysBounceVertical = true
            scrollView.bounces = true
            scrollView.delaysContentTouches = false
            scrollView.refreshControl?.tintColor = .clear
            Self.lockNestedHorizontalPagers(in: scrollView)

            let top = scrollView.adjustedContentInset.top
            let restingY = -top
            // LazyVStack / safeAreaInset can leave a small positive offset so
            // UIRefreshControl thinks we are not at the top until the user scrolls.
            if scrollView.contentOffset.y > restingY, scrollView.contentOffset.y < restingY + 64 {
                scrollView.setContentOffset(
                    CGPoint(x: scrollView.contentOffset.x, y: restingY),
                    animated: false
                )
            }
        }

        private static func findVerticalScrollView(near view: UIView) -> UIScrollView? {
            var ancestor: UIView? = view
            while let current = ancestor {
                if let scrollView = current as? UIScrollView,
                   Self.isVerticalContentScrollView(scrollView) {
                    return scrollView
                }
                ancestor = current.superview
            }
            return nil
        }

        private static func isVerticalContentScrollView(_ scrollView: UIScrollView) -> Bool {
            if scrollView.isPagingEnabled,
               scrollView.contentSize.width > scrollView.bounds.width * 1.2 {
                return false
            }
            return true
        }

        private static func lockNestedHorizontalPagers(in root: UIScrollView) {
            func walk(_ view: UIView) {
                if let nested = view as? UIScrollView, nested !== root {
                    let isHorizontalPager = nested.isPagingEnabled
                        || nested.contentSize.width > nested.bounds.width + 8
                    let isMostlyHorizontal = nested.contentSize.height <= nested.bounds.height + 8
                    if isHorizontalPager && isMostlyHorizontal {
                        nested.isDirectionalLockEnabled = true
                        nested.alwaysBounceVertical = false
                        nested.bounces = nested.contentSize.width > nested.bounds.width
                    }
                }
                for subview in view.subviews {
                    walk(subview)
                }
            }
            walk(root)
        }
    }
}
