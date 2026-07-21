import SwiftUI
import Combine
import UIKit

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
        action: @escaping () async -> Void
    ) -> some View {
        modifier(SplickNativeRefreshableModifier(controller: controller, action: action))
    }
}

private struct SplickNativeRefreshableModifier: ViewModifier {
    let controller: SplickRefreshController?
    let action: () async -> Void

    func body(content: Content) -> some View {
        if let controller {
            content.modifier(
                SplickNativeRefreshableWithController(controller: controller, action: action)
            )
        } else {
            content.refreshable { await action() }
        }
    }
}

private struct SplickNativeRefreshableWithController: ViewModifier {
    @ObservedObject var controller: SplickRefreshController
    let action: () async -> Void

    @StateObject private var refreshHost = SplickScrollRefreshHost()
    @State private var isRefreshing = false
    /// Only used when the underlying scroll view has no `UIRefreshControl` yet.
    @State private var showsFallbackHeader = false

    func body(content: Content) -> some View {
        content
            .background {
                SplickScrollViewRefreshAnchor(host: refreshHost)
            }
            .refreshable {
                await runRefresh()
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if showsFallbackHeader {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(SplickTheme.Colors.primaryGradientStart)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .environment(\.pullToRefreshActive, isRefreshing)
            .preference(key: PullToRefreshActivePreferenceKey.self, value: isRefreshing)
            .onChange(of: controller.requestID) { requestID in
                guard requestID > 0 else { return }
                Task { await runProgrammaticRefresh() }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: showsFallbackHeader)
    }

    @MainActor
    private func runRefresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await action()
    }

    @MainActor
    private func runProgrammaticRefresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let usedNative = await refreshHost.beginRefreshing()
        if !usedNative {
            await playFallbackPullBounce()
        }
        defer {
            isRefreshing = false
            showsFallbackHeader = false
            refreshHost.endRefreshing()
        }
        await action()
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
public final class SplickScrollRefreshHost: ObservableObject {
    public weak var scrollView: UIScrollView?

    public init() {}

    /// Shows the same spinner as a manual pull-to-refresh, with a fast overshoot + bounce-back.
    @discardableResult
    public func beginRefreshing() async -> Bool {
        // Re-resolve in case `.refreshable` attached the control after first layout.
        if scrollView?.refreshControl == nil, let scrollView {
            self.scrollView = Self.findRefreshableScrollView(near: scrollView) ?? scrollView
        }

        guard let scrollView, let refreshControl = scrollView.refreshControl else { return false }
        guard !refreshControl.isRefreshing else { return true }

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
        let resolved = Self.findRefreshableScrollView(near: view)
        if let resolved {
            scrollView = resolved
            return
        }
        if scrollView?.window == nil {
            scrollView = nil
        }
    }

    private static func findRefreshableScrollView(near view: UIView) -> UIScrollView? {
        var preferred: UIScrollView?
        var fallback: UIScrollView?

        func consider(_ scrollView: UIScrollView) {
            guard isLikelyVerticalContentScrollView(scrollView) else { return }
            if scrollView.refreshControl != nil {
                preferred = scrollView
            } else if fallback == nil {
                fallback = scrollView
            }
        }

        var ancestor: UIView? = view
        while let current = ancestor {
            if let scrollView = current as? UIScrollView {
                consider(scrollView)
            }
            ancestor = current.superview
        }

        var container: UIView? = view.superview
        while let current = container {
            enumerateScrollViews(in: current, visit: consider)
            if preferred != nil { break }
            container = current.superview
        }

        return preferred ?? fallback
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
        if scrollView.isPagingEnabled {
            let wide = scrollView.contentSize.width > scrollView.bounds.width * 1.2
            if wide { return false }
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
    }
}
