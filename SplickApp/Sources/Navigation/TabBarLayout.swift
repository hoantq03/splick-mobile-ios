import SwiftUI
import DesignSystem

enum TabBarLayout {
    /// Bottom space reserved so scroll content isn't hidden under the floating tab bar.
    static let floatingClearance: CGFloat = SplickTabBarMetrics.floatingClearance
    static let hiddenClearance: CGFloat = SplickTabBarMetrics.hiddenClearance
    static let tabBarSlideDistance: CGFloat = 120
}

struct FloatingTabBarContentPadding: ViewModifier {
    var isEnabled: Bool = true
    @Environment(\.tabBarScrollState) private var tabBarScrollState

    private var bottomInset: CGFloat {
        guard isEnabled else { return 0 }
        guard let tabBarScrollState else { return TabBarLayout.floatingClearance }
        if tabBarScrollState.isVisible {
            return TabBarLayout.floatingClearance
        }
        return tabBarScrollState.suppressesBottomInset ? 0 : TabBarLayout.hiddenClearance
    }

    func body(content: Content) -> some View {
        content
            .animation(.easeInOut(duration: 0.28), value: bottomInset)
            .modifier(BottomInsetModifier(inset: bottomInset))
    }
}

private struct BottomInsetModifier: ViewModifier {
    let inset: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.safeAreaPadding(.bottom, inset)
        } else {
            content.padding(.bottom, inset)
        }
    }
}
