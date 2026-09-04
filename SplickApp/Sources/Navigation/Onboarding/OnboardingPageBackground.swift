import SwiftUI
import DesignSystem

enum OnboardingBackgroundStyle {
    case brand
    case capture
    case bills
    case friends
}

struct OnboardingPageBackground: View {
    let style: OnboardingBackgroundStyle

    var body: some View {
        ZStack {
            baseFill
            decorativeLayer
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var baseFill: some View {
        switch style {
        case .brand:
            LinearGradient(
                colors: [
                    SplickTheme.Colors.primaryGradientStart.opacity(0.18),
                    SplickTheme.Colors.background,
                    SplickTheme.Colors.primaryGradientEnd.opacity(0.14),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .capture:
            LinearGradient(
                colors: [
                    SplickTheme.Colors.primaryGradientStart.opacity(0.2),
                    SplickTheme.Colors.background,
                    SplickTheme.Colors.primaryGradientEnd.opacity(0.14),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .bills:
            LinearGradient(
                colors: [
                    SplickTheme.Colors.primaryGradientEnd.opacity(0.2),
                    SplickTheme.Colors.background,
                    Color(hex: 0x27AE60).opacity(0.12),
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case .friends:
            LinearGradient(
                colors: [
                    SplickTheme.Colors.primaryGradientStart.opacity(0.18),
                    SplickTheme.Colors.background,
                    SplickTheme.Colors.primaryGradientEnd.opacity(0.16),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var decorativeLayer: some View {
        switch style {
        case .brand:
            brandDecor
        case .capture:
            captureDecor
        case .bills:
            billsDecor
        case .friends:
            friendsDecor
        }
    }

    // MARK: - Brand

    private var brandDecor: some View {
        ZStack {
            Circle()
                .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 2)
                .offset(x: 120, y: -220)

            Circle()
                .fill(SplickTheme.Colors.primaryGradientEnd.opacity(0.2))
                .frame(width: 240, height: 240)
                .blur(radius: 2)
                .offset(x: -130, y: 260)

            Circle()
                .stroke(
                    SplickTheme.Colors.primaryGradientStart.opacity(0.15),
                    lineWidth: 1.5
                )
                .frame(width: 220, height: 220)
                .offset(y: -40)

            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.08))
                    .frame(width: CGFloat(12 + index * 4))
                    .offset(
                        x: CGFloat([-140, 150, -90, 110, -30, 40][index]),
                        y: CGFloat([-280, -200, 220, 280, 80, -120][index])
                    )
            }
        }
    }

    // MARK: - Capture

    private var captureDecor: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.45))
                .frame(width: 140, height: 100)
                .rotationEffect(.degrees(-12))
                .offset(x: -110, y: -200)
                .shadow(color: SplickTheme.Colors.primaryGradientStart.opacity(0.08), radius: 12, y: 6)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .frame(width: 120, height: 88)
                .rotationEffect(.degrees(14))
                .offset(x: 120, y: -160)
                .shadow(color: SplickTheme.Colors.primaryGradientEnd.opacity(0.06), radius: 10, y: 5)

            OnboardingCameraCircleMotif(diameter: 200, style: .watermark)
                .offset(x: 100, y: 280)

            OnboardingCameraCircleMotif(diameter: 88, style: .ring)
                .opacity(0.35)
                .offset(x: -130, y: 240)

            OnboardingCameraCircleMotif(diameter: 120, style: .ring)
                .opacity(0.2)
                .offset(y: -60)

            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart.opacity(0.28))
                .offset(x: -40, y: -200)
        }
    }

    // MARK: - Bills

    private var billsDecor: some View {
        ZStack {
            OnboardingSplitBillView(size: 72)
                .opacity(0.22)
                .rotationEffect(.degrees(-18))
                .offset(x: -90, y: -140)

            OnboardingSplitBillView(size: 56)
                .opacity(0.16)
                .rotationEffect(.degrees(12))
                .offset(x: 120, y: -220)

            Circle()
                .fill(SplickTheme.Colors.primaryGradientEnd.opacity(0.18))
                .frame(width: 160, height: 160)
                .offset(x: -120, y: 220)

            Image(systemName: "equal.circle")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientEnd.opacity(0.22))
                .offset(x: -140, y: -260)
        }
    }

    // MARK: - Friends

    private var friendsDecor: some View {
        ZStack {
            Circle()
                .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.18))
                .frame(width: 220, height: 220)
                .offset(x: -100, y: -210)

            Circle()
                .fill(SplickTheme.Colors.primaryGradientEnd.opacity(0.16))
                .frame(width: 180, height: 180)
                .offset(x: 110, y: 250)

            OnboardingOverlappingHeartsView(size: 90)
                .opacity(0.14)
                .offset(y: -80)

            HStack(spacing: 48) {
                friendNode(size: 44, offsetY: 0)
                friendNode(size: 56, offsetY: -8)
                friendNode(size: 44, offsetY: 4)
            }
            .offset(y: 260)

            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "heart.fill")
                    .font(.system(size: CGFloat(14 + index * 4)))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart.opacity(0.18))
                    .offset(
                        x: CGFloat([-120, 130, 0][index]),
                        y: CGFloat([-300, -240, 300][index])
                    )
            }
        }
    }

    private func friendNode(size: CGFloat, offsetY: CGFloat) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        SplickTheme.Colors.primaryGradientStart.opacity(0.4),
                        SplickTheme.Colors.primaryGradientEnd.opacity(0.35),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .offset(y: offsetY)
    }
}
