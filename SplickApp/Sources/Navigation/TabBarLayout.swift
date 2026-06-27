import SwiftUI
import DesignSystem

enum TabBarLayout {
    /// Bottom space reserved so scroll content isn't hidden under the floating tab bar.
    static let floatingClearance: CGFloat = SplickTabBarMetrics.floatingClearance
    static let hiddenClearance: CGFloat = SplickTabBarMetrics.hiddenClearance
    static let tabBarSlideDistance: CGFloat = 120
}

enum TabBarMotion {
    static let spring = TabBarChromeMotion.spring
    static let show = TabBarChromeMotion.show
}

struct FloatingTabBarContentPadding: ViewModifier {
    var isEnabled: Bool = true

    func body(content: Content) -> some View {
        content.tabBarContentPadding(isEnabled: isEnabled)
    }
}
