import SwiftUI

extension View {
    /// Use `.navigationTitle("…")` plus `.splickProfileToolbar()` instead.
    @available(*, deprecated, message: "Use navigationTitle and splickProfileToolbar")
    public func splickLiftedNavigationTitle(_ title: String, lift: CGFloat = 15) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
    }
}
