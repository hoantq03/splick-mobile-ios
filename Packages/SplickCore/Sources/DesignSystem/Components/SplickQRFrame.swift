import SwiftUI

/// Full-screen Splick brand wash (indigo → teal mesh).
public struct SplickQRScreenBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SplickTheme.Colors.primaryGradientStart.opacity(0.32),
                    SplickTheme.Colors.primaryGradientMid.opacity(0.18),
                    SplickTheme.Colors.primaryGradientEnd.opacity(0.12),
                    SplickTheme.Colors.background,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: -140, y: -120)

            Circle()
                .fill(SplickTheme.Colors.primaryGradientMid.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 50)
                .offset(x: 150, y: 80)

            Circle()
                .fill(SplickTheme.Colors.primaryGradientEnd.opacity(0.14))
                .frame(width: 220, height: 220)
                .blur(radius: 44)
                .offset(x: -60, y: 340)
        }
        .background(SplickTheme.Colors.background)
        .ignoresSafeArea()
    }
}

/// Share/save card mirroring the QR sheet content (title, meta, frame, hint).
public struct SplickQRShareCard: View {
    private let qrImage: UIImage
    private let title: String?
    private let subtitle: String?
    private let meta: String?
    private let hint: String?

    public init(
        qrImage: UIImage,
        title: String? = nil,
        subtitle: String? = nil,
        meta: String? = nil,
        hint: String? = nil
    ) {
        self.qrImage = qrImage
        self.title = title
        self.subtitle = subtitle
        self.meta = meta
        self.hint = hint
    }

    public var body: some View {
        ZStack {
            SplickQRShareBackground()
            VStack(spacing: SplickTheme.Spacing.md) {
                if let title, !title.isEmpty {
                    VStack(spacing: SplickTheme.Spacing.xxs) {
                        Text(title)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        if let meta, !meta.isEmpty {
                            Text(meta)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    .padding(.horizontal, SplickTheme.Spacing.lg)
                }

                SplickQRFrame(qrSize: 240) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                }

                if let hint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SplickTheme.Spacing.xl)
                }
            }
            .padding(.vertical, SplickTheme.Spacing.xl)
            .padding(.horizontal, SplickTheme.Spacing.md)
        }
        .frame(width: 390, height: 640)
        .clipped()
    }

    @MainActor
    public static func render(
        qrImage: UIImage,
        title: String? = nil,
        subtitle: String? = nil,
        meta: String? = nil,
        hint: String? = nil,
        scale: CGFloat = 3
    ) -> UIImage? {
        let renderer = ImageRenderer(
            content: SplickQRShareCard(
                qrImage: qrImage,
                title: title,
                subtitle: subtitle,
                meta: meta,
                hint: hint
            )
        )
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: 390, height: 640)
        return renderer.uiImage
    }
}

/// Same wash as the sheet, clipped to the share card (no safe-area).
private struct SplickQRShareBackground: View {
    var body: some View {
        ZStack {
            SplickTheme.Colors.background
            LinearGradient(
                colors: [
                    SplickTheme.Colors.primaryGradientStart.opacity(0.32),
                    SplickTheme.Colors.primaryGradientMid.opacity(0.18),
                    SplickTheme.Colors.primaryGradientEnd.opacity(0.12),
                    SplickTheme.Colors.background,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: -90, y: -70)
            Circle()
                .fill(SplickTheme.Colors.primaryGradientMid.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 44)
                .offset(x: 110, y: 80)
            Circle()
                .fill(SplickTheme.Colors.primaryGradientEnd.opacity(0.14))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: -20, y: 180)
        }
    }
}

/// Tight gradient border around the QR; “Splick” badge sits on the top edge.
public struct SplickQRFrame<Content: View>: View {
    private let qrSize: CGFloat
    private let isBusy: Bool
    private let content: Content

    private let pad: CGFloat = 12
    private let radius: CGFloat = 16

    public init(
        qrSize: CGFloat = 220,
        isBusy: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.qrSize = qrSize
        self.isBusy = isBusy
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                content
                    .frame(width: qrSize, height: qrSize)
                    .padding(pad)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(SplickTheme.Colors.primaryGradient, lineWidth: 2.5)
                    }
                    .shadow(color: SplickTheme.Colors.primaryGradientStart.opacity(0.20), radius: 16, y: 8)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)

                if isBusy {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                    ProgressView()
                        .controlSize(.regular)
                        .tint(SplickTheme.Colors.primaryGradientStart)
                }
            }

            SplickQRFrameLabel()
                .offset(y: -11)
        }
    }
}

private struct SplickQRFrameLabel: View {
    var body: some View {
        HStack(spacing: 5) {
            SplickLogoMark(size: 16, layout: .markOnly, style: .onDark)
            Text("Splick")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(2.5)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(SplickTheme.Colors.primaryGradient)
        .clipShape(Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5)
        }
        .shadow(color: SplickTheme.Colors.primaryGradientStart.opacity(0.30), radius: 6, y: 3)
    }
}
