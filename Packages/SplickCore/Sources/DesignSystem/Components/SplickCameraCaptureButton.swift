import SwiftUI

/// Brand camera control — same mark and colors in the tab bar and on the capture screen.
public struct SplickCameraCaptureButton: View {
    public var size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            SplickBrandAtmosphere(fillsSafeArea: false)
            SplickLogoMark(
                size: size * 0.72,
                layout: .markOnly,
                style: .fullColor
            )
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.22 : 0.55),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.12), radius: 10, y: 3)
    }
}
