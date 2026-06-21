import SwiftUI
import DesignSystem

/// Telegram-style mascot: tracks the password cursor left→right and covers eyes when password is hidden.
struct PasswordMascotView: View {
    /// Number of characters currently typed.
    let passwordLength: Int
    /// Whether the password field is in plaintext mode.
    let isPasswordVisible: Bool
    /// Max chars before eyes stop moving (approximates visible field width).
    var maxTrackedCharacters: Int = 22

    // MARK: - Derived gaze

    private var gazeT: CGFloat {
        guard passwordLength > 0 else { return 0 }
        return min(1, CGFloat(passwordLength) / CGFloat(max(1, maxTrackedCharacters)))
    }

    /// Pupil offset in points: starts slightly left of centre, sweeps right.
    private var pupilOffsetX: CGFloat {
        let mapped = gazeT * 2 - 1          // -1 … +1
        return mapped * 6
    }

    private var pupilOffsetY: CGFloat {
        // Slight downward look when reading, neutral when empty
        return passwordLength == 0 ? 0 : 2
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .center) {
            face
                .frame(width: 130, height: 130)
        }
        .frame(width: 130, height: 130)
    }

    // MARK: - Face layers

    private var face: some View {
        ZStack(alignment: .center) {
            // ── 1. Head ────────────────────────────────────────────────────────
            Circle()
                .fill(Color(hex: 0xF5CBA7))           // warm skin tone

            Circle()
                .strokeBorder(Color(hex: 0xE0A87C), lineWidth: 2)

            // ── 2. Ears ────────────────────────────────────────────────────────
            ears

            // ── 3. Eyes ────────────────────────────────────────────────────────
            eyes

            // ── 4. Nose ────────────────────────────────────────────────────────
            nose

            // ── 5. Mouth ───────────────────────────────────────────────────────
            mouth

            // ── 6. Arms (swings up to cover eyes when hidden) ──────────────────
            arms
        }
    }

    // MARK: - Ears

    private var ears: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let earW: CGFloat = size * 0.22
            let earH: CGFloat = size * 0.22
            ZStack {
                // left ear
                Ellipse()
                    .fill(Color(hex: 0xE8A87C))
                    .frame(width: earW, height: earH)
                    .position(x: size * 0.22, y: size * 0.16)

                Ellipse()
                    .fill(Color(hex: 0xF5C5A3))
                    .frame(width: earW * 0.55, height: earH * 0.55)
                    .position(x: size * 0.22, y: size * 0.16)

                // right ear
                Ellipse()
                    .fill(Color(hex: 0xE8A87C))
                    .frame(width: earW, height: earH)
                    .position(x: size * 0.78, y: size * 0.16)

                Ellipse()
                    .fill(Color(hex: 0xF5C5A3))
                    .frame(width: earW * 0.55, height: earH * 0.55)
                    .position(x: size * 0.78, y: size * 0.16)
            }
        }
    }

    // MARK: - Eyes

    private var eyes: some View {
        HStack(spacing: 22) {
            eyeball(offsetX: pupilOffsetX, offsetY: pupilOffsetY, open: isPasswordVisible)
            eyeball(offsetX: pupilOffsetX, offsetY: pupilOffsetY, open: isPasswordVisible)
        }
        .offset(y: -12)
        .animation(.easeOut(duration: 0.12), value: pupilOffsetX)
        .animation(.spring(response: 0.32, dampingFraction: 0.75), value: isPasswordVisible)
    }

    private func eyeball(offsetX: CGFloat, offsetY: CGFloat, open: Bool) -> some View {
        ZStack {
            // sclera
            Ellipse()
                .fill(open ? Color.white : Color.white.opacity(0))
                .frame(width: 24, height: open ? 28 : 5)
                .overlay {
                    Ellipse()
                        .strokeBorder(Color(hex: 0xC0956A), lineWidth: 1)
                        .frame(width: 24, height: open ? 28 : 5)
                }

            if open {
                // iris
                Circle()
                    .fill(Color(hex: 0x4A3728))
                    .frame(width: 14, height: 14)
                    .offset(x: offsetX, y: offsetY + 2)

                // pupil
                Circle()
                    .fill(Color.black)
                    .frame(width: 8, height: 8)
                    .offset(x: offsetX, y: offsetY + 2)

                // specular highlight
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 4, height: 4)
                    .offset(x: offsetX - 2, y: offsetY - 1)
            } else {
                // closed eye — curved line
                closedEye
            }
        }
        .frame(width: 28, height: 30)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: open)
    }

    private var closedEye: some View {
        Path { path in
            path.move(to: CGPoint(x: 4, y: 14))
            path.addQuadCurve(
                to: CGPoint(x: 24, y: 14),
                control: CGPoint(x: 14, y: 22)
            )
        }
        .stroke(Color(hex: 0xC0956A), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .frame(width: 28, height: 28)
    }

    // MARK: - Nose

    private var nose: some View {
        Ellipse()
            .fill(Color(hex: 0xC0876A))
            .frame(width: 10, height: 7)
            .offset(y: 4)
    }

    // MARK: - Mouth

    private var mouth: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: 20, y: 0),
                control: CGPoint(x: 10, y: isPasswordVisible ? 10 : 4)
            )
        }
        .stroke(Color(hex: 0xC0876A), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .frame(width: 20, height: 10)
        .offset(y: 18)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPasswordVisible)
    }

    // MARK: - Arms (cover eyes when password is hidden)

    private var arms: some View {
        ZStack {
            arm(isLeft: true, raised: !isPasswordVisible)
            arm(isLeft: false, raised: !isPasswordVisible)
        }
        .animation(
            .spring(response: 0.45, dampingFraction: 0.68),
            value: isPasswordVisible
        )
    }

    private func arm(isLeft: Bool, raised: Bool) -> some View {
        let anchor: UnitPoint = isLeft ? .bottomTrailing : .bottomLeading
        let restAngle: Double = isLeft ? 40 : -40
        let raisedAngle: Double = isLeft ? -30 : 30

        return ZStack(alignment: isLeft ? .bottomTrailing : .bottomLeading) {
            // upper-arm segment
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: 0xE8A87C))
                .frame(width: 22, height: 38)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(hex: 0xC88A60), lineWidth: 1)
                }

            // paw
            Ellipse()
                .fill(Color(hex: 0xF0B890))
                .frame(width: 26, height: 20)
                .offset(y: raised ? 0 : 4)
        }
        .rotationEffect(
            .degrees(raised ? raisedAngle : restAngle),
            anchor: anchor
        )
        .offset(
            x: isLeft ? -38 : 38,
            y: raised ? -28 : 44
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Mascot states") {
    VStack(spacing: 40) {
        HStack(spacing: 30) {
            VStack {
                PasswordMascotView(passwordLength: 0, isPasswordVisible: true)
                Text("empty, visible").font(.caption)
            }
            VStack {
                PasswordMascotView(passwordLength: 8, isPasswordVisible: true)
                Text("typing, visible").font(.caption)
            }
            VStack {
                PasswordMascotView(passwordLength: 8, isPasswordVisible: false)
                Text("typing, hidden").font(.caption)
            }
        }
    }
    .padding()
    .background(Color(.systemBackground))
}
#endif
