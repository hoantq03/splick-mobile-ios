import DesignSystem
import Localization
import SwiftUI

/// Idle lens pills + pinch/pan arc dial, matching Camera.app.
struct CameraNativeZoomChrome: View {
    @EnvironmentObject private var languageService: LanguageService
    let displayZoom: CGFloat
    let presets: [CGFloat]
    let hardware: CameraZoom.Hardware
    let isDialVisible: Bool
    let onSelectPreset: (CGFloat) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            if isDialVisible {
                CameraZoomArcDial(
                    displayZoom: displayZoom,
                    hardware: hardware,
                    presets: presets
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            }

            if !isDialVisible || presets.count > 1 {
                CameraZoomLensPills(
                    displayZoom: displayZoom,
                    presets: presets,
                    onSelectPreset: onSelectPreset
                )
                .opacity(isDialVisible ? 0 : 1)
                .allowsHitTesting(!isDialVisible)
            }
        }
        .frame(height: isDialVisible ? 118 : 44)
        .animation(.easeOut(duration: 0.18), value: isDialVisible)
        .accessibilityLabel(languageService.text(.mediaZoomA11y))
    }
}

struct CameraZoomLensPills: View {
    let displayZoom: CGFloat
    let presets: [CGFloat]
    let onSelectPreset: (CGFloat) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(presets, id: \.self) { preset in
                let selected = abs(displayZoom - preset) <= 0.12
                    || (selectedPreset == preset)
                Button {
                    onSelectPreset(preset)
                } label: {
                    Text(CameraZoom.pillLabel(preset, isSelected: selected, currentDisplay: displayZoom))
                        .font(.system(size: selected ? 13 : 12, weight: .bold))
                        .foregroundStyle(selected ? Color.yellow : .white)
                        .frame(minWidth: selected ? 36 : 30, minHeight: selected ? 36 : 30)
                        .background {
                            Circle()
                                .fill(Color.black.opacity(selected ? 0.55 : 0.38))
                                .overlay {
                                    Circle().stroke(Color.white.opacity(selected ? 0.35 : 0.18), lineWidth: 0.5)
                                }
                        }
                }
                .buttonStyle(.plain)
                .scaleEffect(selected ? 1.08 : 1)
            }
        }
        .animation(.easeOut(duration: 0.16), value: displayZoom)
    }

    private var selectedPreset: CGFloat {
        presets.min(by: { abs($0 - displayZoom) < abs($1 - displayZoom) }) ?? 1
    }
}

struct CameraZoomArcDial: View {
    let displayZoom: CGFloat
    let hardware: CameraZoom.Hardware
    let presets: [CGFloat]

    var body: some View {
        ZStack {
            CameraZoomArcTicks(
                progress: CameraZoom.dialProgress(display: displayZoom, hardware: hardware),
                presets: presets.map { CameraZoom.dialProgress(display: $0, hardware: hardware) }
            )
            VStack(spacing: 6) {
                Spacer()
                Text(CameraZoom.label(displayZoom))
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.yellow)
                    .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
                    .padding(.bottom, 4)
            }
        }
        .frame(height: 118)
        .allowsHitTesting(false)
    }
}

private struct CameraZoomArcTicks: View {
    let progress: CGFloat
    let presets: [CGFloat]

    var body: some View {
        Canvas { context, size in
            let radius = size.width * 0.92
            let center = CGPoint(x: size.width / 2, y: size.height + radius * 0.62)
            let start = Angle.degrees(208).radians
            let end = Angle.degrees(332).radians
            let span = end - start

            var arc = Path()
            arc.addArc(
                center: center,
                radius: radius,
                startAngle: .radians(start),
                endAngle: .radians(end),
                clockwise: false
            )
            context.stroke(arc, with: .color(.white.opacity(0.22)), lineWidth: 2)

            let tickCount = 41
            for i in 0..<tickCount {
                let t = CGFloat(i) / CGFloat(tickCount - 1)
                let isPreset = presets.contains { abs($0 - t) < 0.02 }
                let len: CGFloat = isPreset ? 14 : 7
                strokeTick(
                    context: context,
                    center: center,
                    radius: radius,
                    angle: start + t * span,
                    length: len,
                    color: .white.opacity(isPreset ? 0.9 : 0.35),
                    lineWidth: isPreset ? 2 : 1
                )
            }

            strokeTick(
                context: context,
                center: center,
                radius: radius,
                angle: start + min(max(progress, 0), 1) * span,
                length: 18,
                color: .yellow,
                lineWidth: 3
            )
        }
        .padding(.horizontal, 24)
    }

    private func strokeTick(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        angle: CGFloat,
        length: CGFloat,
        color: Color,
        lineWidth: CGFloat
    ) {
        let dx = cos(angle)
        let dy = sin(angle)
        let inner = CGPoint(x: center.x + dx * (radius - 2), y: center.y + dy * (radius - 2))
        let outer = CGPoint(x: center.x + dx * (radius - 2 - length), y: center.y + dy * (radius - 2 - length))
        var path = Path()
        path.move(to: inner)
        path.addLine(to: outer)
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
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
