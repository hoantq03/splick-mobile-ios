import SwiftUI
import DesignSystem

// MARK: - Camera aperture (twisted iris blades, logo-style)

struct OnboardingCameraApertureView: View {
    var size: CGFloat = 52
    var style: ApertureDisplayStyle = .filled

    enum ApertureDisplayStyle {
        case filled
        case outline
        case watermark
    }

    private let bladeCount = 6
    private let bladeSweep: Double = 58
    private let twistDegrees: Double = 14

    var body: some View {
        ZStack {
            if style != .outline {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                SplickTheme.Colors.primaryGradientStart,
                                SplickTheme.Colors.primaryGradientMid,
                                SplickTheme.Colors.primaryGradientEnd,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            ForEach(0..<bladeCount, id: \.self) { index in
                let base = Double(index) * (360.0 / Double(bladeCount)) - 90
                TwistedIrisBlade(
                    startDegrees: base - bladeSweep / 2,
                    endDegrees: base + bladeSweep / 2,
                    twistDegrees: twistDegrees,
                    innerRatio: 0.34,
                    outerRatio: 0.49
                )
                .fill(bladeFill)
            }

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            SplickTheme.Colors.primaryGradientStart.opacity(0.5),
                            SplickTheme.Colors.primaryGradientEnd.opacity(0.35),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1, size * 0.02)
                )
                .padding(size * 0.04)

            Circle()
                .fill(openingFill)
                .frame(width: size * 0.3, height: size * 0.3)

            Circle()
                .stroke(openingStroke, lineWidth: max(0.5, size * 0.012))
                .frame(width: size * 0.3, height: size * 0.3)
        }
        .frame(width: size, height: size)
    }

    private var bladeFill: Color {
        switch style {
        case .filled, .watermark: .white.opacity(style == .watermark ? 0.88 : 0.94)
        case .outline: SplickTheme.Colors.primaryGradientMid.opacity(0.85)
        }
    }

    private var openingFill: Color {
        switch style {
        case .filled: SplickTheme.Colors.primaryGradientStart.opacity(0.2)
        case .outline: Color.clear
        case .watermark: Color.white.opacity(0.35)
        }
    }

    private var openingStroke: Color {
        switch style {
        case .outline: SplickTheme.Colors.primaryGradientEnd.opacity(0.45)
        default: .white.opacity(0.35)
        }
    }
}

/// Curved iris blade with inner arc twisted relative to outer (spiral shutter).
private struct TwistedIrisBlade: Shape {
    var startDegrees: Double
    var endDegrees: Double
    var twistDegrees: Double
    var innerRatio: CGFloat
    var outerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxR = min(rect.width, rect.height) / 2
        let outerR = maxR * outerRatio
        let innerR = maxR * innerRatio

        let oStart = Angle(degrees: startDegrees)
        let oEnd = Angle(degrees: endDegrees)
        let iStart = Angle(degrees: startDegrees + twistDegrees)
        let iEnd = Angle(degrees: endDegrees + twistDegrees)

        var path = Path()
        path.addArc(center: center, radius: outerR, startAngle: oStart, endAngle: oEnd, clockwise: false)
        path.addArc(center: center, radius: innerR, startAngle: iEnd, endAngle: iStart, clockwise: true)
        path.closeSubpath()
        return path
    }
}

// MARK: - Circle with camera lens motif (focus ring + mini aperture)

struct OnboardingCameraCircleMotif: View {
    var diameter: CGFloat
    var style: MotifStyle = .ring

    enum MotifStyle {
        /// Gradient fill + lens ticks + aperture.
        case filled
        /// Hollow ring + ticks + aperture.
        case ring
        /// Soft blob + faint camera details.
        case watermark
    }

    var body: some View {
        ZStack {
            baseCircle
            focusTicks
            innerFocusRing
            OnboardingCameraApertureView(
                size: diameter * (style == .watermark ? 0.42 : 0.5),
                style: apertureStyle
            )
            if style == .ring {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                SplickTheme.Colors.primaryGradientStart.opacity(0.4),
                                SplickTheme.Colors.primaryGradientEnd.opacity(0.28),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.5, diameter * 0.018)
                    )
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private var apertureStyle: OnboardingCameraApertureView.ApertureDisplayStyle {
        switch style {
        case .filled: .filled
        case .ring: .outline
        case .watermark: .watermark
        }
    }

    @ViewBuilder
    private var baseCircle: some View {
        switch style {
        case .filled:
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            SplickTheme.Colors.primaryGradientStart.opacity(0.2),
                            SplickTheme.Colors.primaryGradientEnd.opacity(0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .ring:
            Circle()
                .fill(Color.clear)
        case .watermark:
            Circle()
                .fill(SplickTheme.Colors.primaryGradientMid.opacity(0.2))
        }
    }

    private var innerFocusRing: some View {
        Circle()
            .stroke(
                SplickTheme.Colors.primaryGradientStart.opacity(style == .watermark ? 0.15 : 0.22),
                style: StrokeStyle(lineWidth: max(0.8, diameter * 0.008), dash: [4, 5])
            )
            .padding(diameter * 0.14)
    }

    private var focusTicks: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(SplickTheme.Colors.primaryGradientStart.opacity(tickOpacity))
                    .frame(width: max(1, diameter * 0.012), height: diameter * 0.055)
                    .offset(y: -diameter * 0.42)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
        }
    }

    private var tickOpacity: Double {
        switch style {
        case .filled: 0.28
        case .ring: 0.35
        case .watermark: 0.2
        }
    }
}

// MARK: - Split dollar bill

struct OnboardingSplitBillView: View {
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            HStack(spacing: 3) {
                billHalf(flipped: false)
                billHalf(flipped: true)
            }

            Rectangle()
                .fill(SplickTheme.Colors.background)
                .frame(width: 3, height: size * 0.72)

            Image(systemName: "scissors")
                .font(.system(size: size * 0.2, weight: .bold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientEnd)
                .offset(y: -size * 0.38)
        }
        .frame(width: size * 1.35, height: size * 0.78)
    }

    private func billHalf(flipped: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0xE8F8F0),
                            Color(hex: 0xD4F0E4),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(SplickTheme.Colors.primaryGradientEnd.opacity(0.45), lineWidth: 1)
                }

            Text("$")
                .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                .foregroundStyle(SplickTheme.Colors.primaryGradientEnd)
                .offset(x: flipped ? size * 0.08 : -size * 0.08)
        }
        .frame(width: size * 0.58, height: size * 0.72)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .rotationEffect(.degrees(flipped ? 5 : -5))
    }
}

// MARK: - Overlapping hearts

struct OnboardingOverlappingHeartsView: View {
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            heart
                .offset(x: -size * 0.18, y: size * 0.04)
                .scaleEffect(0.92)

            heart
                .offset(x: size * 0.2, y: -size * 0.02)
        }
        .frame(width: size * 1.2, height: size)
    }

    private var heart: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size * 0.72, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        SplickTheme.Colors.primaryGradientStart,
                        SplickTheme.Colors.primaryGradientEnd,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: SplickTheme.Colors.primaryGradientStart.opacity(0.25), radius: 6, y: 3)
    }
}
