import SwiftUI

/// When `false`, login content stays off-screen so it can rise after launch loading.
private struct LaunchRevealActiveKey: EnvironmentKey {
    static let defaultValue = true
}

private struct UsesBrandAuthChromeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    public var launchRevealActive: Bool {
        get { self[LaunchRevealActiveKey.self] }
        set { self[LaunchRevealActiveKey.self] = newValue }
    }

    public var usesBrandAuthChrome: Bool {
        get { self[UsesBrandAuthChromeKey.self] }
        set { self[UsesBrandAuthChromeKey.self] = newValue }
    }
}

public enum LoginEntranceMotion {
    public static let rise = Animation.timingCurve(0.16, 0.92, 0.18, 1, duration: 1.42)
    public static let stagger: Duration = .milliseconds(240)
}

public struct LoginRiseIn: ViewModifier {
    public var visible: Bool
    public var distance: CGFloat

    public init(visible: Bool, distance: CGFloat) {
        self.visible = visible
        self.distance = distance
    }

    public func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : distance)
    }
}
