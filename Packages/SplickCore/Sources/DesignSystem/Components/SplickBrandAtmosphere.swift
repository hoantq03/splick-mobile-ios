import SwiftUI

/// Brand canvas and color orbs used on launch loading, login, and camera chrome.
///
/// Orbs are drawn with radial gradients (no SwiftUI `.blur`). Blur allocates a square
/// offscreen buffer that reads as a white/black square when a circular water reveal
/// clips this view down to the tab camera button.
public struct SplickBrandAtmosphere: View {
    public var fillsSafeArea: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.splickBrandPalette) private var brandPalette

    public init(fillsSafeArea: Bool = true) {
        self.fillsSafeArea = fillsSafeArea
    }

    public var body: some View {
        let canvas = Canvas { context, size in
            let w = size.width
            let h = size.height
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(brandPalette.resolvedBrandCanvas(colorScheme))
            )
            drawOrb(
                context: context,
                canvasSize: size,
                offsetX: w * 0.38,
                offsetY: -h * 0.28,
                diameter: w * 0.85,
                softRadius: min(64, w * 0.28),
                color: brandPalette.brandOrange.opacity(0.22)
            )
            drawOrb(
                context: context,
                canvasSize: size,
                offsetX: -w * 0.08,
                offsetY: h * 0.02,
                diameter: w * 0.72,
                softRadius: min(72, w * 0.32),
                color: brandPalette.brandPink.opacity(0.18)
            )
            drawOrb(
                context: context,
                canvasSize: size,
                offsetX: -w * 0.42,
                offsetY: h * 0.32,
                diameter: w * 0.9,
                softRadius: min(68, w * 0.3),
                color: brandPalette.brandBlue.opacity(0.20)
            )
        }
        .allowsHitTesting(false)

        if fillsSafeArea {
            canvas.ignoresSafeArea()
        } else {
            canvas
        }
    }

    private func drawOrb(
        context: GraphicsContext,
        canvasSize: CGSize,
        offsetX: CGFloat,
        offsetY: CGFloat,
        diameter: CGFloat,
        softRadius: CGFloat,
        color: Color
    ) {
        let center = CGPoint(
            x: canvasSize.width / 2 + offsetX,
            y: canvasSize.height / 2 + offsetY
        )
        let coreRadius = diameter / 2
        let outerRadius = coreRadius + softRadius
        let coreStop = max(coreRadius - softRadius, 0) / max(outerRadius, 1)
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - outerRadius,
                y: center.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            )),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: color, location: 0),
                    .init(color: color, location: coreStop),
                    .init(color: color.opacity(0), location: 1),
                ]),
                center: center,
                startRadius: 0,
                endRadius: outerRadius
            )
        )
    }
}
