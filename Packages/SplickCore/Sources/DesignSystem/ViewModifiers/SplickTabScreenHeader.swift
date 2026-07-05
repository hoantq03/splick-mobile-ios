import SwiftUI

private struct SplickTabNavigationBarChromeModifier: ViewModifier {
    var showsBell: Bool = true
    @Environment(\.notificationsPresented) private var notificationsPresented

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(notificationsPresented ? .hidden : .visible, for: .navigationBar)
            .splickProfileToolbar(
                titleDisplayMode: .inline,
                isSuppressed: notificationsPresented,
                showsBell: showsBell && !notificationsPresented
            )
    }
}

extension View {
    /// Matches feed tab navigation chrome: transparent bar, avatar leading, bell trailing.
    public func splickTabNavigationBarChrome(showsBell: Bool = true) -> some View {
        modifier(SplickTabNavigationBarChromeModifier(showsBell: showsBell))
    }

    /// Centered inline title with the same toolbar chrome as the feed tab.
    /// Pass `showsBell: false` to hide the notification bell on tabs that don't need it.
    public func splickTabScreenHeader(_ title: String, showsBell: Bool = true) -> some View {
        navigationTitle("")
            .splickTabNavigationBarChrome(showsBell: showsBell)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .lineLimit(1)
                }
            }
    }
}
