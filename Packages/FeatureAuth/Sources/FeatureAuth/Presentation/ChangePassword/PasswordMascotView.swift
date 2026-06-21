import SwiftUI
import DesignSystem

/// Cute capybara mascot — tracks the password cursor, covers eyes when hidden.
struct PasswordMascotView: View {
    let passwordLength: Int
    let isPasswordVisible: Bool
    var maxTrackedCharacters: Int = 22

    // MARK: - Gaze

    private var gazeT: CGFloat {
        guard passwordLength > 0 else { return 0 }
        return min(1, CGFloat(passwordLength) / CGFloat(max(1, maxTrackedCharacters)))
    }

    private var irisOffsetX: CGFloat { (gazeT * 2 - 1) * 5 }
    private var irisOffsetY: CGFloat { passwordLength == 0 ? 0 : 1.5 }

    // MARK: - Palette

    private let headTop    = Color(hex: 0xD4A574)
    private let headBtm    = Color(hex: 0xA07040)
    private let earOuter   = Color(hex: 0xB8895A)
    private let earInner   = Color(hex: 0xEDC9A8)
    private let snoutFill  = Color(hex: 0xE6C89A)
    private let noseDot    = Color(hex: 0x4A2C14)
    private let blush      = Color(hex: 0xF4A898)
    private let pawFill    = Color(hex: 0xC49A6C)
    private let pawShad    = Color(hex: 0x9B7040)
    private let eyeDark    = Color(hex: 0x221208)

    // MARK: - Body

    var body: some View {
        ZStack {
            head
            ears
            snout
            blushMarks
            eyes
            noseDots
            paws
        }
        .frame(width: 130, height: 130)
        .clipShape(Circle())   // hides paws below the circle; they emerge naturally when raised
        .contentShape(Circle())
    }

    // MARK: - Head

    private var head: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [headTop, headBtm],
                    center: .init(x: 0.38, y: 0.30),
                    startRadius: 8,
                    endRadius: 72
                )
            )
            .shadow(color: headBtm.opacity(0.45), radius: 8, y: 5)
    }

    // MARK: - Ears

    private var ears: some View {
        ZStack {
            // left
            earShape.offset(x: -47, y: -44)
            // right
            earShape.offset(x:  47, y: -44)
        }
    }

    private var earShape: some View {
        ZStack {
            Circle()
                .fill(earOuter)
                .frame(width: 30, height: 30)

            Circle()
                .fill(earInner)
                .frame(width: 16, height: 16)
                .offset(y: 2)
        }
    }

    // MARK: - Snout

    private var snout: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [snoutFill, snoutFill.opacity(0.7)],
                        center: .init(x: 0.4, y: 0.35),
                        startRadius: 2,
                        endRadius: 40
                    )
                )
                .frame(width: 68, height: 48)
                .offset(y: 24)
        }
    }

    // MARK: - Blush

    private var blushMarks: some View {
        HStack(spacing: 52) {
            Ellipse()
                .fill(blush.opacity(0.38))
                .frame(width: 20, height: 12)
            Ellipse()
                .fill(blush.opacity(0.38))
                .frame(width: 20, height: 12)
        }
        .offset(y: 10)
    }

    // MARK: - Eyes

    private var eyes: some View {
        HStack(spacing: 30) {
            eyeball
            eyeball
        }
        .offset(y: -16)
        .animation(.easeOut(duration: 0.10), value: irisOffsetX)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isPasswordVisible)
    }

    private var eyeball: some View {
        ZStack {
            // Sclera — squishes to a line when eyes are closed
            Ellipse()
                .fill(Color.white)
                .frame(width: 22, height: isPasswordVisible ? 26 : 3)
                .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)

            if isPasswordVisible {
                // Iris
                Circle()
                    .fill(eyeDark)
                    .frame(width: 15, height: 15)
                    .offset(x: irisOffsetX, y: irisOffsetY)

                // Specular
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 5, height: 5)
                    .offset(x: irisOffsetX - 3, y: irisOffsetY - 4)

                // Second smaller specular
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 3, height: 3)
                    .offset(x: irisOffsetX + 3, y: irisOffsetY + 2)
            }
        }
        .frame(width: 24, height: 28)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isPasswordVisible)
    }

    // MARK: - Nose dots

    private var noseDots: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(noseDot)
                .frame(width: 7, height: 7)
            Circle()
                .fill(noseDot)
                .frame(width: 7, height: 7)
        }
        .offset(y: 22)
    }

    // MARK: - Paws

    /// Eyes live at y ≈ -16 from centre.
    /// Paws slide from y = +90 (hidden below) → y = -16 (covering eyes).
    private var paws: some View {
        HStack(spacing: 8) {
            pawShape
            pawShape
        }
        .offset(y: isPasswordVisible ? 90 : -14)
        .animation(.spring(response: 0.44, dampingFraction: 0.60), value: isPasswordVisible)
    }

    private var pawShape: some View {
        ZStack(alignment: .top) {
            // Palm — warm rounded rectangle
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [pawFill, pawShad],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 36, height: 32)

            // Three little toe bumps across the top
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(pawFill)
                        .frame(width: 10, height: 10)
                }
            }
            .offset(y: -6)
        }
        .frame(width: 36, height: 40)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Capybara") {
    VStack(spacing: 28) {
        HStack(spacing: 20) {
            VStack(spacing: 6) {
                PasswordMascotView(passwordLength: 0, isPasswordVisible: true)
                Text("idle").font(.caption2).foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                PasswordMascotView(passwordLength: 12, isPasswordVisible: true)
                Text("typing").font(.caption2).foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                PasswordMascotView(passwordLength: 12, isPasswordVisible: false)
                Text("hidden").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
    .padding(24)
    .background(Color(.systemGroupedBackground))
}
#endif
