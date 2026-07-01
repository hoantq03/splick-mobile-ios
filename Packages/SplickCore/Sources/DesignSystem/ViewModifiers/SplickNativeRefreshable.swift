import SwiftUI
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
    @State private var isRefreshing = false

    func body(content: Content) -> some View {
        content
            .refreshable {
                await runRefresh()
            }
            .background {
                SplickProgrammaticRefreshBridge(controller: controller, onRefresh: runRefresh)
            }
            .environment(\.pullToRefreshActive, isRefreshing)
            .preference(key: PullToRefreshActivePreferenceKey.self, value: isRefreshing)
    }

    private func runRefresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await action()
    }
}

// MARK: - Programmatic refresh (tab re-tap)

/// Finds the parent `UIScrollView` and triggers its `UIRefreshControl` (owned by `.refreshable`).
private struct SplickProgrammaticRefreshBridge: UIViewRepresentable {
    let controller: SplickRefreshController?
    let onRefresh: () async -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRefresh: onRefresh)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        context.coordinator.anchorView = view
        context.coordinator.bind(controller: controller)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.anchorView = uiView
        context.coordinator.bind(controller: controller)
    }

    final class Coordinator: NSObject {
        let onRefresh: () async -> Void
        weak var anchorView: UIView?
        private weak var boundController: SplickRefreshController?
        private var refreshTask: Task<Void, Never>?

        init(onRefresh: @escaping () async -> Void) {
            self.onRefresh = onRefresh
        }

        func bind(controller: SplickRefreshController?) {
            boundController = controller
            controller?.bindRefreshTrigger { [weak self] in
                self?.triggerProgrammaticRefresh()
            }
        }

        func triggerProgrammaticRefresh() {
            guard refreshTask == nil else { return }
            refreshTask = Task { @MainActor in
                defer { refreshTask = nil }
                if let scrollView = anchorView?.findVerticalScrollView(),
                   let control = scrollView.refreshControl,
                   !control.isRefreshing {
                    control.beginRefreshing()
                    await onRefresh()
                    control.endRefreshing()
                } else {
                    await onRefresh()
                }
            }
        }
    }
}

private extension UIView {
    func findVerticalScrollView() -> UIScrollView? {
        if let match = ancestors.compactMap({ $0 as? UIScrollView }).first(where: Self.isVerticalFeedStyleScrollView) {
            return match
        }

        var current: UIView? = self
        while let view = current {
            if let scrollView = view.subviews.compactMap({ $0 as? UIScrollView }).first(where: Self.isVerticalFeedStyleScrollView) {
                return scrollView
            }
            current = view.superview
        }

        return nil
    }

    private var ancestors: [UIView] {
        sequence(first: superview, next: { $0?.superview }).compactMap { $0 }
    }

    private static func isVerticalFeedStyleScrollView(_ scrollView: UIScrollView) -> Bool {
        if scrollView.isPagingEnabled { return false }

        if scrollView.contentSize == .zero {
            return true
        }

        let contentWidth = scrollView.contentSize.width
        let boundsWidth = max(scrollView.bounds.width, 1)
        let contentHeight = scrollView.contentSize.height
        let boundsHeight = max(scrollView.bounds.height, 1)

        let isWideCarousel = contentWidth > boundsWidth * 1.4
        let isPrimarilyVertical = contentHeight > boundsHeight * 1.02 || contentWidth <= boundsWidth * 1.05
        return isPrimarilyVertical && !isWideCarousel
    }
}
