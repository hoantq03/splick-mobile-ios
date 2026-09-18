import SwiftUI
import Combine
import UIKit
import Localization

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

    private var shiftsContentUnderChrome: Bool { chromeTopInset > 0 }

    private var heldRefreshPull: CGFloat { 60 }

    private var visiblePull: CGFloat {
        guard shiftsContentUnderChrome else { return refreshHost.pullDistance }
        if isRefreshing || showsFallbackHeader {
            return max(chromeContentBounce, refreshHost.pullDistance, heldRefreshPull)
        }
        return max(chromeContentBounce, refreshHost.pullDistance)
    }

    private var isIndicatorVisible: Bool {
        isRefreshing || showsFallbackHeader || visiblePull > 4
    }

    private func spinnerTopPadding(zStackGlobalMinY: CGFloat) -> CGFloat {
        if shiftsContentUnderChrome {
            let spinner: CGFloat = 28
            let chromeOverlap = max(0, chromeTopInset - zStackGlobalMinY)
            return chromeOverlap + max(8, (visiblePull - spinner) / 2)
        }
        return refreshHost.spinnerOverlayTopPadding()
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            chromeShiftedContent(content)
                .background {
                    SplickScrollViewRefreshAnchor(host: refreshHost)
                }
                .refreshable {
                    await handleSystemRefreshable()
                }

            let isLoading = isRefreshing || showsFallbackHeader
            GeometryReader { geo in
                SplickSpinner(
                    size: .medium,
                    rotationDegrees: isLoading
                        ? nil
                        : (shiftsContentUnderChrome
                            ? Double(visiblePull / SplickScrollRefreshHost.fullRotationPull) * 360
                            : refreshHost.pullRotationDegrees)
                )
                .frame(maxWidth: .infinity)
                .padding(
                    .top,
                    spinnerTopPadding(zStackGlobalMinY: geo.frame(in: .global).minY)
                )
                .opacity(isIndicatorVisible ? 1 : 0)
                .accessibilityHidden(!isIndicatorVisible)
            }
            .allowsHitTesting(false)
        }
            .environment(\.pullToRefreshActive, isRefreshing)
            .preference(key: PullToRefreshActivePreferenceKey.self, value: isRefreshing)
            .onReceive(controller.$requestID) { requestID in
                guard requestID > handledRequestID else { return }
                handledRequestID = requestID
                Task { await runProgrammaticRefresh() }
            }
            .onChange(of: isIndicatorVisible) { visible in
                Task { @MainActor in
                    tabBarScrollState?.setRefreshIndicatorVisible(visible)
                }
            }
            .onAppear {
                refreshHost.applyClearSystemTint()
                refreshHost.onPullCommit = {
                    Task { await runRefresh() }
                }
            }
    }

    @ViewBuilder
    private func chromeShiftedContent(_ content: Content) -> some View {
        if shiftsContentUnderChrome {
            content.offset(y: visiblePull)
        } else {
            content
        }
    }

    @MainActor
    private func handleSystemRefreshable() async {
        // System `.refreshable` already crossed UIKit's threshold. Do not drop the
        // refresh when custom pull-tracking failed to attach (feed UIHostingController).
        await runRefresh()
        if refreshHost.currentPullDistance() < 8 {
            refreshHost.resetGesturePeak()
        }
    }

    @MainActor
    private func runRefresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        let task = Task { @MainActor in
            isRefreshing = true
            if shiftsContentUnderChrome, chromeContentBounce < heldRefreshPull {
                withAnimation(.easeOut(duration: 0.12)) {
                    chromeContentBounce = heldRefreshPull
                }
            }
            defer {
                if shiftsContentUnderChrome {
                    withAnimation(.easeOut(duration: 0.22)) {
                        chromeContentBounce = 0
                    }
                }
                isRefreshing = false
            }
            await action()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    @MainActor
    private func runProgrammaticRefresh() async {
        guard refreshTask == nil, !isRefreshing else { return }
        isRefreshing = true
        refreshHost.prepareProgrammaticCommit()
        if shiftsContentUnderChrome {
            await playChromeContentBounce()
        } else {
            let usedNative = await refreshHost.beginRefreshing()
            if !usedNative {
                await playFallbackPullBounce()
            }
        }
        defer {
            showsFallbackHeader = false
            isRefreshing = false
            withAnimation(.easeOut(duration: 0.22)) {
                chromeContentBounce = 0
            }
            refreshHost.endRefreshing()
        }
        await action()
    }

    @MainActor
    private func playChromeContentBounce() async {
        let hold = heldRefreshPull
        let overshoot = hold + SplickProgrammaticRefreshMotion.overshoot
        withAnimation(.easeOut(duration: SplickProgrammaticRefreshMotion.pullDuration)) {
            chromeContentBounce = overshoot
        }
        try? await Task.sleep(
            nanoseconds: UInt64(SplickProgrammaticRefreshMotion.pullDuration * 1_000_000_000)
        )
        withAnimation(
            .spring(
                response: SplickProgrammaticRefreshMotion.bounceDuration,
                dampingFraction: SplickProgrammaticRefreshMotion.bounceDamping
            )
        ) {
            chromeContentBounce = hold
        }
        try? await Task.sleep(nanoseconds: 80_000_000)
    }

    @MainActor
    private func playFallbackPullBounce() async {
        withAnimation(.easeOut(duration: 0.14)) {
            showsFallbackHeader = true
        }
        try? await Task.sleep(nanoseconds: 140_000_000)
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
    @Published public private(set) var pullDistance: CGFloat = 0
    public var pullRotationDegrees: Double {
        Double(pullDistance / Self.fullRotationPull) * 360
    }
    public private(set) var completedFullRotation = false
    var onPullCommit: (() -> Void)?

    private var offsetObservation: NSKeyValueObservation?
    private var panRecognizer: UIPanGestureRecognizer?
    private var maxPullInGesture: CGFloat = 0
    private var wasDragging = false
    private var didThresholdHaptic = false
    private let thresholdHaptic = UIImpactFeedbackGenerator(style: .medium)

    static let fullRotationPull = SplickSpinner.fullRotationPullDistance(for: .medium)

    public override init() {}

    public func applyClearSystemTint() {
        scrollView?.refreshControl?.tintColor = .clear
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
    }

    /// Sit in the revealed PTR gap: below chrome that overlaps this scroll view, then centered in the pull.
    public func spinnerOverlayTopPadding() -> CGFloat {
        let pull = pullDistance
        let spinner: CGFloat = 28
        guard let scrollView else { return max(8, (pull - spinner) / 2) }
        let inset = scrollView.adjustedContentInset.top
        let refreshBand = scrollView.refreshControl?.isRefreshing == true
            ? max(scrollView.refreshControl?.bounds.height ?? 0, 0)
            : 0
        let fromInset = max(0, inset - refreshBand)
        let originY = scrollView.convert(CGPoint.zero, to: nil).y
        let safeTop = scrollView.window?.safeAreaInsets.top ?? 59
        let overlappingNav = max(0, (safeTop + 44) - originY)
        let chrome = max(fromInset, overlappingNav)
        return chrome + max(8, (pull - spinner) / 2)
    }

    public func currentPullDistance() -> CGFloat {
        guard let scrollView else { return 0 }
        return max(0, -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top))
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
        let resolved = findRefreshableScrollView(near: view)
        if let resolved {
            if scrollView !== resolved {
                objectWillChange.send()
            }
            bind(to: resolved)
            applyClearSystemTint()
            return
        }
        if scrollView?.window == nil {
            unbindScrollView()
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
        scrollView = nil
    }

    private func installPullTrackingIfNeeded() {
        guard let scrollView else { return }
        if offsetObservation == nil {
            offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                if Thread.isMainThread {
                    self?.handleContentOffsetChange()
                } else {
                    DispatchQueue.main.async {
                        self?.handleContentOffsetChange()
                    }
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
            wasDragging = true
            thresholdHaptic.prepare()
            handleContentOffsetChange()
        case .changed:
            handleContentOffsetChange()
        case .ended, .cancelled, .failed:
            handleContentOffsetChange()
            handleFingerRelease()
        default:
            break
        }
    }

    private func handleContentOffsetChange() {
        let pull = currentPullDistance()
        if pull > 2 {
            maxPullInGesture = max(maxPullInGesture, pull)
        }
        if !didThresholdHaptic, maxPullInGesture >= Self.fullRotationPull {
            didThresholdHaptic = true
            thresholdHaptic.impactOccurred(intensity: 1)
        }
        if abs(pullDistance - pull) > 0.4 {
            pullDistance = pull
        }
    }

    private func handleFingerRelease() {
        wasDragging = false
        completedFullRotation = maxPullInGesture >= Self.fullRotationPull
        if completedFullRotation {
            onPullCommit?()
        } else if pullDistance < 4 {
            pullDistance = 0
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
