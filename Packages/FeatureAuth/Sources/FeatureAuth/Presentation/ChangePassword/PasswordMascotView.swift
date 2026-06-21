import SwiftUI
import DesignSystem

/// Capybara mascot: watches while you type, covers its eyes when the password is hidden.
struct PasswordMascotView: View {
    /// Characters typed so far.
    let passwordLength: Int
    /// Whether the password field is showing plaintext.
    let isPasswordVisible: Bool
    /// Approximate visible character capacity of the field (controls pupil travel).
    var maxTrackedCharacters: Int = 22

    // MARK: - Gaze maths

    private var gazeT: CGFloat {
        guard passwordLength > 0 else { return 0 }
        return min(1, CGFloat(passwordLength) / CGFloat(max(1, maxTrackedCharacters)))
    }

    /// Iris offset: sweeps left → right as characters are typed.
    private var irisOffsetX: CGFloat { (gazeT * 2 - 1) * 5 }
    private var irisOffsetY: CGFloat { passwordLength == 0 ? 0 : 1.5 }

    // MARK: - Palette

    private let fur          = Color(hex: 0x9B7B5B)   // main coat
    private let furDark      = Color(hex: 0x7A5C3E)   // shadow / outline
    private let furLight     = Color(hex: 0xBFA080)   // highlight / snout
    private let snoutColor   = Color(hex: 0xC4A07A)   // muzzle box
    private let noseColor    = Color(hex: 0x3D2214)   // nostrils
    private let eyeColor     = Color(hex: 0x221208)   // iris
    private let earInner     = Color(hex: 0xD4A882)   // inner ear

    // MARK: - Body

    var body: some View {
        // Extra vertical room so paws don't clip at bottom when at rest
        ZStack(alignment: .top) {
            capybaraFace
        }
        .frame(width: 130, height: 150)   // 130 face + 20 paw room below
        .contentShape(Rectangle())
    }

    // MARK: - Face

    private var capybaraFace: some View {
        ZStack(alignment: .center) {
            // Head
            Circle()
                .fill(fur)
                .frame(width: 130, height: 130)

            Circle()
                .strokeBorder(furDark.opacity(0.5), lineWidth: 1.5)
                .frame(width: 130, height: 130)

            // Ears (behind head highlight, so drawn first)
            ears

            // Snout block
            snout

            // Eyes
            eyes

            // Nostrils
            nostrils

            // Paws — rendered LAST so they appear in front of everything
            paws
        }
        .frame(width: 130, height: 130)
    }

    // MARK: - Ears

    private var ears: some View {
        ZStack {
            // Left ear
            Ellipse()
                .fill(furDark)
                .frame(width: 28, height: 24)
                .offset(x: -46, y: -46)

            Ellipse()
                .fill(earInner)
                .frame(width: 16, height: 14)
                .offset(x: -46, y: -46)

            // Right ear
            Ellipse()
                .fill(furDark)
                .frame(width: 28, height: 24)
                .offset(x: 46, y: -46)

            Ellipse()
                .fill(earInner)
                .frame(width: 16, height: 14)
                .offset(x: 46, y: -46)
        }
    }

    // MARK: - Snout

    private var snout: some View {
        ZStack {
            // Muzzle box — distinctive capybara rectangular snout
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(snoutColor)
                .frame(width: 56, height: 38)
                .offset(y: 22)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(furDark.opacity(0.3), lineWidth: 1)
                .frame(width: 56, height: 38)
                .offset(y: 22)
        }
    }

    // MARK: - Nostrils

    private var nostrils: some View {
        HStack(spacing: 10) {
            Ellipse()
                .fill(noseColor)
                .frame(width: 8, height: 7)
            Ellipse()
                .fill(noseColor)
                .frame(width: 8, height: 7)
        }
        .offset(y: 20)
    }

    // MARK: - Eyes

    private var eyes: some View {
        HStack(spacing: 26) {
            singleEye
            singleEye
        }
        .offset(y: -8)
        .animation(.easeOut(duration: 0.10), value: irisOffsetX)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isPasswordVisible)
    }

    private var singleEye: some View {
        ZStack {
            // White sclera — shrinks to a slit when hidden
            Ellipse()
                .fill(Color.white)
                .frame(width: 20, height: isPasswordVisible ? 22 : 3)
                .overlay {
                    Ellipse()
                        .strokeBorder(furDark.opacity(0.25), lineWidth: 1)
                        .frame(width: 20, height: isPasswordVisible ? 22 : 3)
                }

            if isPasswordVisible {
                // Iris
                Circle()
                    .fill(eyeColor)
                    .frame(width: 13, height: 13)
                    .offset(x: irisOffsetX, y: irisOffsetY + 1)

                // Specular
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 4, height: 4)
                    .offset(x: irisOffsetX - 2, y: irisOffsetY - 2)
            }
        }
        .frame(width: 22, height: 24)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isPasswordVisible)
    }

    // MARK: - Paws (slide straight up to cover the eyes)

    private var paws: some View {
        HStack(spacing: 10) {
            pawShape
            pawShape
        }
        // Eyes are at y = -8 relative to face centre.
        // Paws need to cover them → raise to y ≈ -8 (rest: y = +72, below circle).
        .offset(y: isPasswordVisible ? 72 : -8)
        .animation(
            .spring(response: 0.42, dampingFraction: 0.64),
            value: isPasswordVisible
        )
    }

    private var pawShape: some View {
        ZStack {
            // Palm
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(fur)
                .frame(width: 34, height: 30)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(furDark.opacity(0.45), lineWidth: 1.5)
                }

            // Three stubby toes at top
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(furLight)
                        .frame(width: 7, height: 10)
                        .overlay {
                            Capsule()
                                .strokeBorder(furDark.opacity(0.3), lineWidth: 1)
                        }
                }
            }
            .offset(y: -14)
        }
        .frame(width: 34, height: 44)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Capybara states") {
    VStack(spacing: 32) {
        HStack(spacing: 24) {
            VStack(spacing: 6) {
                PasswordMascotView(passwordLength: 0, isPasswordVisible: true)
                Text("idle · visible").font(.caption2).foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                PasswordMascotView(passwordLength: 10, isPasswordVisible: true)
                Text("typing · visible").font(.caption2).foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                PasswordMascotView(passwordLength: 10, isPasswordVisible: false)
                Text("typing · hidden").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
    .padding(24)
    .background(Color(.systemGroupedBackground))
}
#endif
