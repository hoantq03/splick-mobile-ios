import SwiftUI

extension View {
    /// Bounce-always so `.refreshable` works on short post-detail content.
    /// Top clearance lives on the scroll *content* (`splickDetailScrollContentTopPadding`),
    /// not `contentMargins(.scrollContent)` — that extra margin made pull-to-refresh
    /// need a huge drag and could double-space the post under the nav bar.
    public func splickDetailScrollInsets() -> some View {
        modifier(SplickDetailScrollInsetsModifier())
    }

    /// Tight gap below the inline nav title. NavigationStack already lays the
    /// scroll view below the bar; do not add chrome height again.
    public func splickDetailScrollContentTopPadding() -> some View {
        padding(.top, SplickTheme.Spacing.xxs)
    }
}

private struct SplickDetailScrollInsetsModifier: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 16.4, *) {
                content.scrollBounceBehavior(.always, axes: .vertical)
            } else {
                content
            }
        }
        .scrollContentBackground(.hidden)
        .background(SplickTheme.Colors.background)
    }
}
