import SwiftUI
import DesignSystem

/// Cute capybara peeking at the password field — eyes track typing, paws cover when hidden.
struct PasswordMascotView: View {
    let passwordLength: Int
    let isPasswordVisible: Bool
    var maxTrackedCharacters: Int = 22

    // MARK: - Gaze

    private var gazeT: CGFloat {
        guard passwordLength > 0 else { return 0.15 }
        return 0.15 + min(1, CGFloat(passwordLength) / CGFloat(max(1, maxTrackedCharacters))) * 0.7
    }

    private var pupilOffsetX: CGFloat { (gazeT - 0.5) * 10 }

    // MARK: - Palette

    private let furLight   = Color(hex: 0xDDB88A)
    private let furMid     = Color(hex: 0xC4956A)
    private let furDark    = Color(hex: 0x9A7048)
    private let snoutLight = Color(hex: 0xF0D5B5)
    private let snoutMid   = Color(hex: 0xE4C4A0)
    private let belly      = Color(hex: 0xF5E6D0)
    private let earInner   = Color(hex: 0xF2C9A8)
    private let nose       = Color(hex: 0x5C3D28)
    private let eyeBrown   = Color(hex: 0x3D2818)
    private let blush      = Color(hex: 0xF0A898)

    // Eye centre positions (within 168×152 canvas)
    private let leftEyeCenter  = CGPoint(x: 58, y: 52)
    private let rightEyeCenter = CGPoint(x: 110, y: 52)

    var body: some View {
        ZStack(alignment: .top) {
            character
            coveringPaws
        }
        .frame(width: 168, height: 152)
    }

    // MARK: - Character stack

    private var character: some View {
        ZStack(alignment: .top) {
            // Shoulders / chest peeking from below
            shoulders

            // Main head block — wide & flat, capybara signature shape
            headBlock

            ears

            // Face (above snout plane)
            eyesLayer

            blushCheeks

            // Block snout — lighter, wider than tall
            snoutBlock

            whiskers

            tinySmile
        }
    }

    // MARK: - Shoulders

    private var shoulders: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [furMid, furDark.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 118, height: 44)
            .offset(y: 98)
            .shadow(color: furDark.opacity(0.25), radius: 6, y: 4)
    }

    // MARK: - Head

    private var headBlock: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [furLight, furMid],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 136, height: 88)
                .overlay(alignment: .topLeading) {
                    // Soft highlight
                    Ellipse()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 48, height: 28)
                        .offset(x: 18, y: 12)
                }
                .shadow(color: furDark.opacity(0.22), radius: 10, y: 6)

            // Belly patch on lower head
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(belly.opacity(0.55))
                .frame(width: 72, height: 28)
                .offset(y: 58)
        }
        .offset(y: 14)
    }

    // MARK: - Ears

    private var ears: some View {
        ZStack {
            ear.offset(x: -46, y: 8)
            ear.offset(x: 46, y: 8)
        }
    }

    private var ear: some View {
        ZStack {
            Capsule()
                .fill(furDark)
                .frame(width: 22, height: 26)
            Capsule()
                .fill(earInner)
                .frame(width: 12, height: 16)
                .offset(y: 3)
        }
    }

    // MARK: - Snout

    private var snoutBlock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [snoutLight, snoutMid],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 96, height: 54)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 96, height: 18)
                }

            // Nostrils — capybara has nostrils on top of snout
            HStack(spacing: 14) {
                nostril
                nostril
            }
            .offset(y: -6)

            // Subtle nose bridge line
            Capsule()
                .fill(nose.opacity(0.35))
                .frame(width: 2, height: 10)
                .offset(y: -14)
        }
        .offset(y: 78)
    }

    private var nostril: some View {
        Capsule()
            .fill(nose)
            .frame(width: 9, height: 7)
    }

    private var whiskers: some View {
        ZStack {
            whiskerBundle(isLeft: true).position(x: 28, y: 88)
            whiskerBundle(isLeft: false).position(x: 140, y: 88)
        }
    }

    private func whiskerBundle(isLeft: Bool) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(nose.opacity(0.35))
                    .frame(width: isLeft ? 16 : 16, height: 1.5)
                    .rotationEffect(.degrees(isLeft ? Double(-8 + index * 8) : Double(8 - index * 8)))
                    .offset(y: CGFloat(index - 1) * 5)
            }
        }
    }

    private var tinySmile: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: 22, y: 0),
                control: CGPoint(x: 11, y: isPasswordVisible ? 7 : 3)
            )
        }
        .stroke(nose.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .frame(width: 22, height: 8)
        .offset(y: 108)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPasswordVisible)
    }

    // MARK: - Blush

    private var blushCheeks: some View {
        ZStack {
            Ellipse()
                .fill(blush.opacity(0.32))
                .frame(width: 22, height: 13)
                .position(x: 38, y: 72)
            Ellipse()
                .fill(blush.opacity(0.32))
                .frame(width: 22, height: 13)
                .position(x: 130, y: 72)
        }
    }

    // MARK: - Eyes

    private var eyesLayer: some View {
        ZStack {
            eye(at: leftEyeCenter)
            eye(at: rightEyeCenter)
        }
        .animation(.easeOut(duration: 0.11), value: pupilOffsetX)
        .animation(.spring(response: 0.3, dampingFraction: 0.78), value: isPasswordVisible)
    }

    private func eye(at center: CGPoint) -> some View {
        ZStack {
            if isPasswordVisible {
                // White sclera — slightly round, kawaii proportions
                Ellipse()
                    .fill(Color.white)
                    .frame(width: 22, height: 24)
                    .shadow(color: .black.opacity(0.07), radius: 1.5, y: 1)

                // Iris
                Circle()
                    .fill(eyeBrown)
                    .frame(width: 14, height: 14)
                    .offset(x: pupilOffsetX, y: 1)

                // Pupil
                Circle()
                    .fill(Color.black.opacity(0.88))
                    .frame(width: 8, height: 8)
                    .offset(x: pupilOffsetX, y: 1)

                // Sparkle
                Circle()
                    .fill(Color.white)
                    .frame(width: 4.5, height: 4.5)
                    .offset(x: pupilOffsetX - 3, y: -3)

                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: pupilOffsetX + 3, y: 2)
            } else {
                // Closed — gentle curved line (paws cover anyway)
                Path { path in
                    path.move(to: CGPoint(x: 2, y: 11))
                    path.addQuadCurve(
                        to: CGPoint(x: 18, y: 11),
                        control: CGPoint(x: 10, y: 16)
                    )
                }
                .stroke(furDark.opacity(0.7), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: 20, height: 20)
            }
        }
        .position(center)
    }

    // MARK: - Covering paws

    private var coveringPaws: some View {
        ZStack {
            paw(side: .left)
            paw(side: .right)
        }
        .animation(.spring(response: 0.46, dampingFraction: 0.62), value: isPasswordVisible)
    }

    private enum PawSide { case left, right }

    private func paw(side: PawSide) -> some View {
        let isLeft = side == .left
        // Rest: tucked at chest. Raised: over corresponding eye.
        let restX: CGFloat = isLeft ? 28 : 140
        let restY: CGFloat = 128
        let coverX: CGFloat = isLeft ? leftEyeCenter.x : rightEyeCenter.x
        let coverY: CGFloat = leftEyeCenter.y + 2

        return CapybaraPawShape()
            .fill(
                LinearGradient(
                    colors: [furLight, furMid],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                CapybaraPawShape()
                    .stroke(furDark.opacity(0.35), lineWidth: 1.2)
            }
            .frame(width: 40, height: 36)
            .shadow(color: furDark.opacity(isPasswordVisible ? 0 : 0.2), radius: 4, y: 2)
            .scaleEffect(x: isLeft ? 1 : -1, y: 1)
            .position(
                x: isPasswordVisible ? restX : coverX,
                y: isPasswordVisible ? restY : coverY
            )
            .rotationEffect(
                .degrees(isPasswordVisible ? (isLeft ? -8 : 8) : 0),
                anchor: .bottom
            )
    }
}

// MARK: - Paw shape (chunky capybara forepaw with toes)

private struct CapybaraPawShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Palm
        path.addRoundedRect(
            in: CGRect(x: w * 0.08, y: h * 0.28, width: w * 0.84, height: h * 0.62),
            cornerSize: CGSize(width: 10, height: 10)
        )

        // Three toes
        let toeW = w * 0.22
        let toeH = h * 0.32
        for i in 0..<3 {
            let x = w * 0.12 + CGFloat(i) * (w * 0.28)
            path.addEllipse(in: CGRect(x: x, y: 0, width: toeW, height: toeH))
        }

        return path
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Capybara mascot") {
    VStack(spacing: 32) {
        HStack(spacing: 24) {
            VStack(spacing: 8) {
                PasswordMascotView(passwordLength: 0, isPasswordVisible: true)
                Text("idle").font(.caption2).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                PasswordMascotView(passwordLength: 14, isPasswordVisible: true)
                Text("typing").font(.caption2).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                PasswordMascotView(passwordLength: 14, isPasswordVisible: false)
                Text("hidden").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
    .padding(28)
    .background(Color(.systemGroupedBackground))
}
#endif
