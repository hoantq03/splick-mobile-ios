import Localization
import SwiftUI

/// Single centered zoom readout. Tap cycles 1× / 2× / 5× / 10×.
struct CameraNativeZoomChrome: View {
    @EnvironmentObject private var languageService: LanguageService
    let displayZoom: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(CameraZoom.label(displayZoom))
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundColor(Color.yellow)
                .frame(minWidth: 36, minHeight: 36)
                .background {
                    Circle()
                        .fill(Color.black.opacity(0.55))
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageService.text(.mediaZoomA11y))
        .accessibilityValue(CameraZoom.label(displayZoom))
    }
}

struct CameraFocusReticle: View {
    let indicator: CameraFocusIndicator

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(Color.yellow, lineWidth: 1.4)
            .frame(width: 72, height: 72)
            .position(indicator.point)
            .id(indicator.token)
            .transition(.scale(scale: 1.18).combined(with: .opacity))
            .allowsHitTesting(false)
    }
}
