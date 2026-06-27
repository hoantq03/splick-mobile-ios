import SwiftUI

extension View {
    /// Centered inline navigation title with profile avatar (leading) and notification bell (trailing).
    public func splickTabScreenHeader(_ title: String) -> some View {
        navigationTitle(title)
            .splickProfileToolbar(titleDisplayMode: .inline)
    }
}
