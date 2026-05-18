import SwiftUI

enum TabBarLayout {
    /// Bottom space reserved so scroll content isn't hidden under the floating tab bar.
    static let floatingClearance: CGFloat = 88
    static let hiddenClearance: CGFloat = 16
    static let tabBarSlideDistance: CGFloat = 120
}

struct FloatingTabBarContentPadding: ViewModifier {
    @Environment(\.tabBarScrollState) private var tabBarScrollState

    private var bottomInset: CGFloat {
        guard let tabBarScrollState else { return TabBarLayout.floatingClearance }
        return tabBarScrollState.isVisible ? TabBarLayout.floatingClearance : TabBarLayout.hiddenClearance
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
