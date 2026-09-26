import SwiftUI

public enum SplickToolbarCircularChromeMetrics {
    /// Circular liquid-glass plate behind toolbar avatar / bell.
    public static let diameter: CGFloat = 44
    /// Avatar image inside the chrome ring (`.compact` = 40pt).
    public static let avatarDiameter: CGFloat = 40
    /// Bell chrome + badge corner clearance (8pt × 2).
    public static let toolbarSlotWidth: CGFloat = 60
}

/// Circular Liquid Glass plate for navigation-bar toolbar controls (iOS 26+).
public struct SplickCircularToolbarChrome: View {
    let diameter: CGFloat

    public init(diameter: CGFloat = SplickToolbarCircularChromeMetrics.diameter) {
        self.diameter = diameter
    }

    public var body: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(.clear)
                .frame(width: diameter, height: diameter)
                .glassEffect(.regular)
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: diameter, height: diameter)
        }
    }
}
