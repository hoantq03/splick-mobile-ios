import SwiftUI
import Combine
import UIKit

// MARK: - Programmatic refresh

@MainActor
public final class SplickRefreshController: ObservableObject {
    public init() {}

    /// Bumped by `refresh()` so SwiftUI `.onChange` can start a programmatic pull-to-refresh.
    @Published public private(set) var requestID: Int = 0

    /// Shows the refresh UI and runs the bound refresh action.
    public func refresh() {
        requestID += 1
    }
}

// MARK: - Same-tab tap behavior

public extension View {
    /// When the user re-taps the active tab: scroll to top if scrolled down, otherwise pull-to-refresh.
    func splickSameTabTapBehavior(
        scrollTopID: String,
        scrollProxy: ScrollViewProxy,
        refreshController: SplickRefreshController,
        isAtTop: @escaping () -> Bool,
        isEnabled: @escaping () -> Bool = { true }
    ) -> some View {
        modifier(
            SplickSameTabTapBehaviorModifier(
                scrollTopID: scrollTopID,
                scrollProxy: scrollProxy,
                refreshController: refreshController,
                isAtTop: isAtTop,
                isEnabled: isEnabled
            )
        )
    }
}

private struct SplickSameTabTapBehaviorModifier: ViewModifier {
    let scrollTopID: String
    let scrollProxy: ScrollViewProxy
    let refreshController: SplickRefreshController
    let isAtTop: () -> Bool
    let isEnabled: () -> Bool

    @Environment(\.tabBarScrollState) private var tabBarScrollState
    @Environment(\.feedSegmentScrollState) private var feedSegmentScrollState
    @Environment(\.sameTabTapHandlingEnabled) private var sameTabTapHandlingEnabled

    private var sameTabTapPublisher: AnyPublisher<Void, Never> {
        tabBarScrollState?.sameTabTapSubject.eraseToAnyPublisher()
            ?? Empty().eraseToAnyPublisher()
    }

    func body(content: Content) -> some View {
        content.onReceive(sameTabTapPublisher) { _ in
            guard sameTabTapHandlingEnabled, isEnabled() else { return }
            if isAtTop() {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                refreshController.refresh()
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    scrollProxy.scrollTo(scrollTopID, anchor: .top)
                }
                // Next same-tab tap should refresh once we've returned to top.
                tabBarScrollState?.reset()
                feedSegmentScrollState?.reset()
            }
        }
    }
}
