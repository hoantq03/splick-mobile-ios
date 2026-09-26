import SwiftUI

private struct ScrollChromeTrackingEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

private struct SameTabTapHandlingEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// When false, scroll-driven tab bar / feed segment chrome must not update (e.g. inactive pager page).
    public var scrollChromeTrackingEnabled: Bool {
        get { self[ScrollChromeTrackingEnabledKey.self] }
        set { self[ScrollChromeTrackingEnabledKey.self] = newValue }
    }

    /// When false, same-tab tap scroll-to-top / refresh is ignored (inactive main tabs).
    public var sameTabTapHandlingEnabled: Bool {
        get { self[SameTabTapHandlingEnabledKey.self] }
        set { self[SameTabTapHandlingEnabledKey.self] = newValue }
    }
}
