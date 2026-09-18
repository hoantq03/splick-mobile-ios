//
//  ProfileCardView.swift
//  SplickClip
//

import DesignSystem
import Localization
import Storage
import SwiftUI

struct ProfileCardView: View {
    @EnvironmentObject private var viewModel: ClipInviteViewModel
    @EnvironmentObject private var languageService: LanguageService

    @State private var dragOffset: CGSize = .zero
    @State private var breathingAngle: Double = 0

    var body: some View {
        ZStack {
            SplickBrandAtmosphere()
            ClipLivingAtmosphere()

            VStack(spacing: 0) {
                Spacer(minLength: SplickTheme.Spacing.sm)

                Group {
                    switch viewModel.state {
                    case .idle:
                        IdleScanCardView()
                    case .loading:
                        LoadingCardSkeletonView()
                    case .loaded(let profile):
                        LoadedProfileCardContent(profile: profile, viewModel: viewModel)
                    case .inviteSent:
                        InviteSuccessCardView()
                    case .error(let title, let message):
                        ErrorCardView(title: title, message: message) {
                            viewModel.retry()
                        }
                    }
                }
                .rotation3DEffect(.degrees(effectiveAngleY), axis: (x: 0, y: 1, z: 0), perspective: 0.62)
                .rotation3DEffect(.degrees(effectiveAngleX), axis: (x: -1, y: 0, z: 0), perspective: 0.62)
                .scaleEffect(cardScale)
                .gesture(tiltGesture)
                .animation(.spring(response: 0.46, dampingFraction: 0.84), value: stateIdentity)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                    removal: .opacity
                ))

                Spacer(minLength: SplickTheme.Spacing.sm)
            }
        }
        .overlay(alignment: .top) {
            brandHeader
                .padding(.top, 6)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true)) {
                breathingAngle = 1
            }
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 7) {
            SplickLogoMark(size: 16, layout: .markOnly, style: .onDark)

            Text("SPLICK")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(Color.white.opacity(0.96))
        }
        .padding(.horizontal, 16)
        .frame(height: 37)
        .background {
            Capsule()
                .fill(Color.black)
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.16),
                                    Color.white.opacity(0.04),
                                    Color.clear,
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(0.8)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6)
                }
                .shadow(color: Color.black.opacity(0.45), radius: 10, y: 6)
        }
        .accessibilityLabel("Splick")
    }

    private var tiltGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                withAnimation(.interactiveSpring(response: 0.16, dampingFraction: 0.9)) {
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                let momentumX = (value.predictedEndTranslation.width - value.translation.width) * 0.08
                let momentumY = (value.predictedEndTranslation.height - value.translation.height) * 0.08
                dragOffset = CGSize(
                    width: value.translation.width + momentumX,
                    height: value.translation.height + momentumY
                )
                withAnimation(.spring(response: 0.86, dampingFraction: 0.68)) {
                    dragOffset = .zero
                }
            }
    }

    private var cardScale: CGFloat {
        1 + (hypot(dragOffset.width, dragOffset.height) / 2400)
    }

    private var effectiveAngleX: Double {
        Double(dragOffset.height / 16).clamped(to: -14...14) + ((breathingAngle * 1.4) - 0.7)
    }

    private var effectiveAngleY: Double {
        Double(dragOffset.width / 16).clamped(to: -14...14) + ((sin(breathingAngle * .pi) * 1.6) - 0.8)
    }

    private var stateIdentity: String {
        switch viewModel.state {
        case .idle: return "idle"
        case .loading: return "loading"
        case .loaded(let profile): return "loaded-\(profile.userId.uuidString)"
        case .inviteSent: return "sent"
        case .error: return "error"
        }
    }
}

// MARK: - Living atmosphere

private struct ClipLivingAtmosphere: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Circle()
                    .fill(SplickTheme.Colors.brandOrange.opacity(colorScheme == .dark ? 0.34 : 0.2))
                    .frame(width: w * 0.78)
                    .blur(radius: 54)
                    .offset(x: drift ? w * 0.34 : w * 0.22, y: drift ? -h * 0.32 : -h * 0.24)
                Circle()
                    .fill(SplickTheme.Colors.brandPink.opacity(colorScheme == .dark ? 0.28 : 0.16))
                    .frame(width: w * 0.7)
                    .blur(radius: 62)
                    .offset(x: drift ? -w * 0.18 : -w * 0.04, y: drift ? h * 0.06 : -h * 0.02)
                Circle()
                    .fill(SplickTheme.Colors.brandBlue.opacity(colorScheme == .dark ? 0.32 : 0.18))
                    .frame(width: w * 0.92)
                    .blur(radius: 58)
                    .offset(x: drift ? -w * 0.38 : -w * 0.28, y: drift ? h * 0.3 : h * 0.22)

                TimelineView(.animation(minimumInterval: 1 / 24, paused: false)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        for i in 0..<18 {
                            let seed = Double(i * 53)
                            let x = (sin(seed * 0.7) * 0.5 + 0.5) * size.width
                            let y = (cos(seed * 1.1) * 0.5 + 0.5) * size.height
                            let twinkle = (sin(t * (1.1 + Double(i % 4) * 0.28) + seed) * 0.5 + 0.5)
                            let radius = 0.7 + twinkle * 1.8
                            let color: Color = [SplickTheme.Colors.brandBlue, SplickTheme.Colors.brandPink, SplickTheme.Colors.brandOrange][i % 3]
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                                with: .color(color.opacity(colorScheme == .dark ? 0.22 + twinkle * 0.45 : 0.1 + twinkle * 0.22))
                            )
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 6.4).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

// MARK: - Idle

private struct IdleScanCardView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        let pulse = (sin(t * 1.15 - Double(index) * 0.7) * 0.5 + 0.5)
                        Circle()
                            .stroke(
                                SplickTheme.Colors.brandWordmarkGradient.opacity(0.22 + pulse * 0.45),
                                lineWidth: 1.6
                            )
                            .frame(width: CGFloat(88 + index * 38), height: CGFloat(88 + index * 38))
                            .scaleEffect(0.92 + pulse * 0.16)
                    }

                    Circle()
                        .trim(from: 0, to: 0.22)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    SplickTheme.Colors.brandBlue.opacity(0),
                                    SplickTheme.Colors.brandBlue,
                                    SplickTheme.Colors.brandPink,
                                    SplickTheme.Colors.brandOrange.opacity(0),
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 154, height: 154)
                        .rotationEffect(.degrees(t * 110))

                    Circle()
                        .fill(SplickTheme.Colors.brandWordmarkGradient)
                        .frame(width: 82, height: 82)
                        .shadow(color: SplickTheme.Colors.brandPink.opacity(0.5), radius: 22)
                        .overlay {
                            SplickLogoView(layout: .markOnly, style: .onDark)
                                .frame(width: 38, height: 38)
                        }
                }
                .frame(height: 176)
            }

            VStack(spacing: 8) {
                Text(languageService.text(.clipIdleTitle))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(nameGradient)
                    .multilineTextAlignment(.center)

                Text(languageService.text(.clipIdleSubtitle))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
        }
        .padding(SplickTheme.Spacing.xl)
        .frame(maxWidth: 360)
        .clipGlassCard()
    }

    private var nameGradient: LinearGradient {
        colorScheme == .dark
            ? LinearGradient(colors: [.white, SplickTheme.Colors.brandBlue, SplickTheme.Colors.brandPink], startPoint: .leading, endPoint: .trailing)
            : SplickTheme.Colors.brandWordmarkGradient
    }
}

// MARK: - Loading

private struct LoadingCardSkeletonView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            Circle()
                .fill(shimmerFill)
                .frame(width: 108, height: 108)
                .overlay {
                    Circle().strokeBorder(SplickTheme.Colors.brandWordmarkGradient.opacity(0.45), lineWidth: 2.4)
                }

            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(shimmerFill)
                    .frame(width: 176, height: 22)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(shimmerFill)
                    .frame(width: 108, height: 14)
            }

            SplickSpinner(size: .medium)
        }
        .padding(SplickTheme.Spacing.xl)
        .frame(maxWidth: 360)
        .clipGlassCard()
        .onAppear {
            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
        .accessibilityLabel("Loading")
    }

    private var shimmerFill: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05), location: 0),
                .init(color: Color.white.opacity(colorScheme == .dark ? 0.22 : 0.7), location: 0.5),
                .init(color: Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05), location: 1),
            ],
            startPoint: .init(x: -1 + shimmerPhase * 2.5, y: 0.25),
            endPoint: .init(x: shimmerPhase * 2.5, y: 0.75)
        )
    }
}

// MARK: - Loaded

private struct LoadedProfileCardContent: View {
    let profile: ClipPublicProfileDTO
    let viewModel: ClipInviteViewModel

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.colorScheme) private var colorScheme
    @State private var reveal = false
    @State private var glow = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                SplickTheme.Colors.brandBlue.opacity(glow ? (colorScheme == .dark ? 0.55 : 0.28) : 0.12),
                                SplickTheme.Colors.brandPink.opacity(0.16),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 86
                        )
                    )
                    .frame(width: 168, height: 168)

                AvatarOrbit()

                AvatarView(
                    imageURL: profile.avatarURL,
                    name: profile.displayName,
                    size: .profile,
                    userId: profile.userId
                )
                .overlay {
                    TimelineView(.animation(minimumInterval: 1 / 24, paused: false)) { timeline in
                        Circle()
                            .strokeBorder(
                                AngularGradient(
                                    colors: [
                                        SplickTheme.Colors.brandBlue,
                                        SplickTheme.Colors.brandPink,
                                        SplickTheme.Colors.brandOrange,
                                        SplickTheme.Colors.brandBlue,
                                    ],
                                    center: .center
                                ),
                                lineWidth: 3
                            )
                            .rotationEffect(.degrees(timeline.date.timeIntervalSinceReferenceDate * 28))
                    }
                }
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.28 : 0.7), lineWidth: 0.8)
                }
                .shadow(color: SplickTheme.Colors.brandPink.opacity(0.32), radius: 18, y: 8)
            }

            VStack(spacing: 7) {
                Text(profile.displayName)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(nameGradient)
                    .multilineTextAlignment(.center)
                    .shadow(color: SplickTheme.Colors.brandBlue.opacity(0.18), radius: 8, y: 2)

                Text("@\(profile.username)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.brandBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(SplickTheme.Colors.brandBlue.opacity(colorScheme == .dark ? 0.18 : 0.1), in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(SplickTheme.Colors.brandBlue.opacity(0.28), lineWidth: 1)
                    )

                Text(languageService.text(.clipInviteTitle))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(reveal ? 1 : 0)
            .offset(y: reveal ? 0 : 10)

            if !profile.visibleStats.isEmpty {
                HStack(spacing: 10) {
                    ForEach(profile.visibleStats, id: \.labelKey) { stat in
                        VStack(spacing: 3) {
                            Text(formatCount(stat.value))
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                            Text(languageService.text(stat.labelKey))
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(SplickTheme.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(colorScheme == .dark ? 0.28 : 0.8),
                                            SplickTheme.Colors.brandBlue.opacity(0.28),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                }
                .opacity(reveal ? 1 : 0)
            }

            ClipConnectButton(
                title: languageService.text(actionTitleKey),
                isEnabled: profile.resolvedFriendStatus == .none,
                isLoading: viewModel.isInviting
            ) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.sendInvite()
            }

            if profile.resolvedFriendStatus != .friends {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.openFullApp(username: profile.username)
                } label: {
                    HStack(spacing: 4) {
                        Text(languageService.text(.clipGetFullApp))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Text(languageService.text(.clipTagline))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(22)
        .frame(maxWidth: 360)
        .clipGlassCard()
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glow = true
            }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84).delay(0.04)) {
                reveal = true
            }
        }
    }

    private var actionTitleKey: L10nKey {
        switch profile.resolvedFriendStatus {
        case .friends: return .clipAlreadyFriends
        case .pending: return .clipPending
        case .none: return .clipConnectAction
        }
    }

    private var nameGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [.white, Color(hex: 0x7DD3FC), SplickTheme.Colors.brandPink],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [Color(hex: 0x0F172A), SplickTheme.Colors.brandBlue, SplickTheme.Colors.brandPink],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func formatCount(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }
}

private struct AvatarOrbit: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    let angle = (Double(i) / 6.0) * .pi * 2 + t * 0.7
                    Circle()
                        .fill(
                            [SplickTheme.Colors.brandBlue, SplickTheme.Colors.brandPink, SplickTheme.Colors.brandOrange][i % 3]
                        )
                        .frame(width: i.isMultiple(of: 2) ? 5.5 : 3.5, height: i.isMultiple(of: 2) ? 5.5 : 3.5)
                        .shadow(color: SplickTheme.Colors.brandPink.opacity(0.7), radius: 4)
                        .offset(x: cos(angle) * 68, y: sin(angle) * 68)
                        .opacity(0.55 + 0.4 * sin(t * 2.1 + Double(i)))
                }
            }
            .frame(width: 160, height: 160)
        }
        .allowsHitTesting(false)
    }
}

private struct ClipConnectButton: View {
    let title: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.extraLarge, style: .continuous)
                    .fill(isEnabled ? AnyShapeStyle(SplickTheme.Colors.brandWordmarkGradient) : AnyShapeStyle(Color.primary.opacity(0.08)))

                if isEnabled {
                    TimelineView(.animation(minimumInterval: 1 / 20, paused: false)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let x = CGFloat((sin(t * 1.15) * 0.5) + 0.5)
                        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.extraLarge, style: .continuous)
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: max(0, x - 0.2)),
                                        .init(color: .white.opacity(0.38), location: x),
                                        .init(color: .clear, location: min(1, x + 0.2)),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .blendMode(.overlay)
                    }
                }

                HStack(spacing: 8) {
                    if isLoading {
                        SplickSpinner(size: .small, usesBrandColors: false)
                    } else {
                        Image(systemName: isEnabled ? "person.badge.plus.fill" : "checkmark.seal.fill")
                            .font(.system(.body, weight: .bold))
                        Text(title)
                            .font(.system(.body, design: .rounded, weight: .bold))
                    }
                }
                .foregroundStyle(isEnabled ? Color.white : SplickTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .overlay(
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.extraLarge, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.35 : 0.12), lineWidth: 1)
            )
            .shadow(color: isEnabled ? SplickTheme.Colors.brandPink.opacity(0.38) : .clear, radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Success / Error

private struct InviteSuccessCardView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.colorScheme) private var colorScheme
    @State private var bounce = false

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(SplickTheme.Colors.brandWordmarkGradient.opacity(0.35), lineWidth: 8)
                    .frame(width: bounce ? 118 : 72, height: bounce ? 118 : 72)
                    .opacity(bounce ? 0 : 0.8)

                Circle()
                    .fill(SplickTheme.Colors.brandWordmarkGradient)
                    .frame(width: 88, height: 88)
                    .shadow(color: SplickTheme.Colors.brandBlue.opacity(0.45), radius: 20)
                    .scaleEffect(bounce ? 1 : 0.5)

                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
                    .scaleEffect(bounce ? 1 : 0.28)
            }
            .frame(height: 120)

            VStack(spacing: 8) {
                Text(languageService.text(.clipInviteSentTitle))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color(hex: 0x0F172A))
                Text(languageService.text(.clipInviteSentMessage))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(SplickTheme.Spacing.xl)
        .frame(maxWidth: 360)
        .clipGlassCard()
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                bounce = true
            }
        }
    }
}

private struct ErrorCardView: View {
    let title: String
    let message: String
    let onRetry: () -> Void

    @EnvironmentObject private var languageService: LanguageService

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(SplickTheme.Colors.error.opacity(0.14))
                    .frame(width: 84, height: 84)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.error)
            }

            VStack(spacing: SplickTheme.Spacing.xs) {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            SplickButton(languageService.text(.commonTryAgain), style: .secondary, action: onRetry)
        }
        .padding(SplickTheme.Spacing.xl)
        .frame(maxWidth: 360)
        .clipGlassCard()
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}

// MARK: - Glass card

private struct ClipGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.42),
                                    Color.clear,
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )

                    TimelineView(.animation(minimumInterval: 1 / 18, paused: false)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let x = (sin(t * 0.55) * 0.5) + 0.2
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white.opacity(colorScheme == .dark ? 0.16 : 0.28), location: x),
                                        .init(color: .clear, location: 1),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.overlay)
                    }
                    .allowsHitTesting(false)

                    SplickLogoView(layout: .markOnly, style: .monochrome)
                        .frame(width: 128, height: 128)
                        .opacity(colorScheme == .dark ? 0.05 : 0.04)
                        .rotationEffect(.degrees(16))
                        .offset(x: 48, y: -36)
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.5 : 0.95),
                                    SplickTheme.Colors.brandBlue.opacity(0.55),
                                    SplickTheme.Colors.brandPink.opacity(0.45),
                                    SplickTheme.Colors.brandOrange.opacity(0.4),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.35
                        )
                }
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.1), radius: 28, y: 14)
            .shadow(color: SplickTheme.Colors.brandBlue.opacity(colorScheme == .dark ? 0.22 : 0.1), radius: 18, y: 8)
            .shadow(color: SplickTheme.Colors.brandOrange.opacity(0.12), radius: 22, y: 10)
            .padding(.horizontal, SplickTheme.Spacing.lg)
    }
}

private extension View {
    func clipGlassCard() -> some View {
        modifier(ClipGlassCardModifier())
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

#Preview("Idle") {
    let language = LanguageService(userDefaults: UserDefaultsService())
    return ProfileCardView()
        .environmentObject(ClipInviteViewModel(languageService: language))
        .environmentObject(language)
        .environmentObject(ThemeService(userDefaults: UserDefaultsService()))
}

#Preview("Loaded") {
    let language = LanguageService(userDefaults: UserDefaultsService())
    let viewModel = ClipInviteViewModel(languageService: language)
    viewModel.state = .loaded(
        ClipPublicProfileDTO(
            userId: UUID(),
            username: "splick",
            displayName: "Splick",
            avatarUrl: nil,
            friendCount: 12,
            postCount: 4,
            friendStatus: nil
        )
    )
    return ProfileCardView()
        .environmentObject(viewModel)
        .environmentObject(language)
        .environmentObject(ThemeService(userDefaults: UserDefaultsService()))
}
