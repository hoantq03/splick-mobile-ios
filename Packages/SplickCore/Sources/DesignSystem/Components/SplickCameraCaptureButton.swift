import SwiftUI

/// Brand camera control — same mark and colors in the tab bar and on the capture screen.
///
/// Uses radial gradients (no SwiftUI `.blur` / `drawingGroup`) so the control never
/// allocates a square offscreen buffer that reads as a soft square halo around the button.
public struct SplickCameraCaptureButton: View {
    public var size: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.splickBrandPalette) private var brandPalette

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(brandPalette.resolvedBrandCanvas(colorScheme))
            Canvas { context, canvasSize in
                let w = canvasSize.width
                let h = canvasSize.height
                drawOrb(
                    context: context,
                    canvasSize: canvasSize,
                    offsetX: w * 0.38,
                    offsetY: -h * 0.28,
                    diameter: w * 0.85,
                    color: brandPalette.brandOrange.opacity(0.34)
                )
                drawOrb(
                    context: context,
                    canvasSize: canvasSize,
                    offsetX: -w * 0.08,
                    offsetY: h * 0.02,
                    diameter: w * 0.72,
                    color: brandPalette.brandPink.opacity(0.28)
                )
                drawOrb(
                    context: context,
                    canvasSize: canvasSize,
                    offsetX: -w * 0.42,
                    offsetY: h * 0.32,
                    diameter: w * 0.9,
                    color: brandPalette.brandBlue.opacity(0.32)
                )
            }
            .allowsHitTesting(false)
            SplickLogoMark(
                size: size * 0.72,
                layout: .markOnly,
                style: .fullColor
            )
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .contentShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.22 : 0.55),
                    lineWidth: 1
                )
        }
        // Shadow only the circular silhouette — never a square drawingGroup texture.
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.12),
            radius: 10,
            y: 3
        )
    }

    private func drawOrb(
        context: GraphicsContext,
        canvasSize: CGSize,
        offsetX: CGFloat,
        offsetY: CGFloat,
        diameter: CGFloat,
        color: Color
    ) {
        let center = CGPoint(
            x: canvasSize.width / 2 + offsetX,
            y: canvasSize.height / 2 + offsetY
        )
        let radius = diameter / 2
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: diameter,
            height: diameter
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: color, location: 0),
                    .init(color: color, location: 0.45),
                    .init(color: color.opacity(0), location: 1),
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }
}
