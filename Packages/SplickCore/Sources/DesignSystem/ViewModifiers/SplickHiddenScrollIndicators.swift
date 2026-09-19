import SwiftUI
import UIKit

/// App-wide: no system scroll bars on `UIScrollView` (SwiftUI `ScrollView` / `List` included).
public enum SplickHiddenScrollIndicators {
    public static func apply() {
        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false
    }
}

public extension View {
    /// Hides SwiftUI scroll indicators (iOS 16+) in this subtree.
    func splickHiddenScrollIndicators() -> some View {
        modifier(SplickHiddenScrollIndicatorsModifier())
    }
}

private struct SplickHiddenScrollIndicatorsModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollIndicators(.hidden)
        } else {
            content
        }
    }
}
