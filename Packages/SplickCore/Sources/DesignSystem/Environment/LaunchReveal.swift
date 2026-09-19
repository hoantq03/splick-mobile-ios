import SwiftUI

/// When `false`, login content stays off-screen until splash marks have finished sliding away.
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
    /// Critically damped rise: starts from rest, eases into place. ~610ms visual settle.
    public static let riseMilliseconds: Int64 = 608
    /// 4–5 large sections: 56ms stagger, ~224ms cascade (under the 300ms cap).
    public static let stagger: Duration = .milliseconds(56)
    public static let rise = Animation.spring(
        response: 0.61,
        dampingFraction: 1.0,
        blendDuration: 0.14
    )
}

public struct LoginRiseIn: ViewModifier {
    public var visible: Bool
    public var distance: CGFloat

    public init(visible: Bool, distance: CGFloat) {
        self.visible = visible
        self.distance = distance
    }

    public func body(content: Content) -> some View {
        content.modifier(LoginRiseTranslation(progress: visible ? 1 : 0, distance: distance))
    }
}

/// Interpolated every frame so the spring can ease into rest.
private struct LoginRiseTranslation: ViewModifier, Animatable {
    var progress: CGFloat
    var distance: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .offset(y: (1 - progress) * distance)
    }
}
