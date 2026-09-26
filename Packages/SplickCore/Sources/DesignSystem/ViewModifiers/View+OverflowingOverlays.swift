import SwiftUI

public extension View {
    /// Lets overlays (password requirements, menus) draw past scroll bounds on iOS 17+.
    @ViewBuilder
    func splickAllowsOverflowingOverlays() -> some View {
        if #available(iOS 17.0, *) {
            scrollClipDisabled()
        } else {
            self
        }
    }
}
