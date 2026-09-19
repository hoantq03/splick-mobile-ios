import SwiftUI

/// Brand canvas and color orbs used on launch loading and login.
public struct SplickBrandAtmosphere: View {
    public var fillsSafeArea: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.splickBrandPalette) private var brandPalette

    public init(fillsSafeArea: Bool = true) {
        self.fillsSafeArea = fillsSafeArea
    }

    public var body: some View {
        let canvas = GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                brandPalette.resolvedBrandCanvas(colorScheme)

                Circle()
                    .fill(brandPalette.brandOrange.opacity(0.22))
                    .frame(width: w * 0.85)
                    .blur(radius: min(64, w * 0.28))
                    .offset(x: w * 0.38, y: -h * 0.28)
                Circle()
                    .fill(brandPalette.brandPink.opacity(0.18))
                    .frame(width: w * 0.72)
                    .blur(radius: min(72, w * 0.32))
                    .offset(x: -w * 0.08, y: h * 0.02)
                Circle()
                    .fill(brandPalette.brandBlue.opacity(0.20))
                    .frame(width: w * 0.9)
                    .blur(radius: min(68, w * 0.3))
                    .offset(x: -w * 0.42, y: h * 0.32)
            }
            .frame(width: w, height: h)
        }
        .allowsHitTesting(false)

        if fillsSafeArea {
            canvas.ignoresSafeArea()
        } else {
            canvas
        }
    }
}
