import SwiftUI

/// Cream canvas and color orbs used on launch loading and login.
public struct SplickBrandAtmosphere: View {
    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                SplickTheme.Colors.brandCanvas

                Circle()
                    .fill(SplickTheme.Colors.brandOrange.opacity(0.22))
                    .frame(width: w * 0.85)
                    .blur(radius: 64)
                    .offset(x: w * 0.38, y: -h * 0.28)
                Circle()
                    .fill(SplickTheme.Colors.brandPink.opacity(0.18))
                    .frame(width: w * 0.72)
                    .blur(radius: 72)
                    .offset(x: -w * 0.08, y: h * 0.02)
                Circle()
                    .fill(SplickTheme.Colors.brandBlue.opacity(0.20))
                    .frame(width: w * 0.9)
                    .blur(radius: 68)
                    .offset(x: -w * 0.42, y: h * 0.32)
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
