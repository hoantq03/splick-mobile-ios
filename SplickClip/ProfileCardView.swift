//
//  ProfileCardView.swift
//  SplickClip
//
//  Ultra-premium 3D glassmorphism profile card for Splick App Clip.
//  Fully supports adaptive Dark Mode and Light Mode with Splick brand theme.
//

import SwiftUI

// MARK: - Root View

struct ProfileCardView: View {
    @EnvironmentObject var viewModel: ClipInviteViewModel
    @Environment(\.colorScheme) private var colorScheme

    // Interactive 3D tilt gesture state
    @State private var dragOffset: CGSize = .zero

    // Ambient floating 3D breathing animation
    @State private var breathingAngle: Double = 0

    var body: some View {
        ZStack {
            // Adaptive ambient mesh background
            BackgroundAuraView()

            VStack(spacing: 0) {
                // Header brand pill
                SplickBrandHeader()
                    .padding(.top, 18)

                Spacer(minLength: 16)

                // 3D Interactive Card Container
                Group {
                    switch viewModel.state {
                    case .idle:
                        IdleScanCardView()
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            ))

                    case .loading:
                        LoadingCardSkeletonView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))

                    case .loaded(let profile):
                        LoadedProfileCardContent(profile: profile, viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.92).combined(with: .opacity),
                                removal: .scale(scale: 0.92).combined(with: .opacity)
                            ))

                    case .inviteSent:
                        InviteSuccessCardView()
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.85).combined(with: .opacity),
                                removal: .opacity
                            ))

                    case .error(let message):
                        ErrorCardView(message: message) {
                            viewModel.retry()
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                // 3D Card tilt calculation
                .rotation3DEffect(
                    .degrees(effectiveAngleY),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.7
                )
                .rotation3DEffect(
                    .degrees(effectiveAngleX),
                    axis: (x: -1, y: 0, z: 0),
                    perspective: 0.7
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.88)) {
                                dragOffset = value.translation
                            }
                        }
                        .onEnded { value in
                            // Include slight release inertia then glide smoothly back with spring physics
                            let momentumX = (value.predictedEndTranslation.width - value.translation.width) * 0.12
                            let momentumY = (value.predictedEndTranslation.height - value.translation.height) * 0.12
                            dragOffset = CGSize(
                                width: value.translation.width + momentumX,
                                height: value.translation.height + momentumY
                            )
                            withAnimation(.spring(response: 0.85, dampingFraction: 0.68, blendDuration: 0.2)) {
                                dragOffset = .zero
                            }
                        }
                )

                Spacer(minLength: 16)

                // Footer hint
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption2)
                    Text("Nghiêng thẻ hoặc vuốt nhẹ để tương tác 3D")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                }
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color(hex: 0x64748B).opacity(0.75))
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            // Subtle perpetual 3D breathing motion
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                breathingAngle = 1.0
            }
        }
    }

    // Effective tilt angles combining gesture + gentle breathing
    private var effectiveAngleX: Double {
        let gestureTilt = Double(dragOffset.height / 12).clamped(to: -22...22)
        let breathingTilt = (breathingAngle * 2.2) - 1.1
        return gestureTilt + breathingTilt
    }

    private var effectiveAngleY: Double {
        let gestureTilt = Double(dragOffset.width / 12).clamped(to: -22...22)
        let breathingTilt = (sin(breathingAngle * .pi) * 2.6) - 1.3
        return gestureTilt + breathingTilt
    }
}

// MARK: - Background Ambient Aura (Adaptive)

private struct BackgroundAuraView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                // Deep cosmic base
                Color(hex: 0x0A0A14).ignoresSafeArea()

                // Ambient violet orb
                Circle()
                    .fill(Color(hex: 0x5B6CFF).opacity(pulse ? 0.35 : 0.22))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: pulse ? -80 : -50, y: pulse ? -140 : -100)

                // Ambient teal/cyan orb
                Circle()
                    .fill(Color(hex: 0x00F5D4).opacity(pulse ? 0.28 : 0.18))
                    .frame(width: 280, height: 280)
                    .blur(radius: 75)
                    .offset(x: pulse ? 90 : 60, y: pulse ? 120 : 80)
            } else {
                // Soft iridescent light background
                LinearGradient(
                    colors: [
                        Color(hex: 0xF8FAFC),
                        Color(hex: 0xEEF2FF),
                        Color(hex: 0xF0FDFA)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Soft pastel violet orb
                Circle()
                    .fill(Color(hex: 0x5B6CFF).opacity(pulse ? 0.18 : 0.10))
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)
                    .offset(x: pulse ? -70 : -40, y: pulse ? -120 : -90)

                // Soft pastel teal orb
                Circle()
                    .fill(Color(hex: 0x4ECDC4).opacity(pulse ? 0.20 : 0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 70)
                    .offset(x: pulse ? 80 : 50, y: pulse ? 110 : 70)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }
}

// MARK: - Brand Header (Adaptive)

private struct SplickBrandHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image("SplickLogoMark")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 18, height: 24)
                .shadow(color: Color(hex: 0x5B6CFF).opacity(0.8), radius: 6)

            Text("SPLICK")
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .tracking(2.5)
                .foregroundStyle(colorScheme == .dark ? .white : Color(hex: 0x0F172A))

            Text("CLIP")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(colorScheme == .dark ? Color(hex: 0x4ECDC4) : Color(hex: 0x0D9488))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    colorScheme == .dark
                        ? Color(hex: 0x4ECDC4).opacity(0.18)
                        : Color(hex: 0x0D9488).opacity(0.14),
                    in: Capsule()
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(
                            colors: [
                                colorScheme == .dark ? .white.opacity(0.3) : .white.opacity(0.85),
                                colorScheme == .dark ? .white.opacity(0.06) : Color(hex: 0x5B6CFF).opacity(0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                )
        }
        .shadow(
            color: colorScheme == .dark ? .black.opacity(0.35) : Color(hex: 0x5B6CFF).opacity(0.12),
            radius: 12,
            y: 4
        )
    }
}

// MARK: - Idle Scanning State (Adaptive)

private struct IdleScanCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var wavePulse: Bool = false

    var body: some View {
        VStack(spacing: 28) {
            // 3D Concentric NFC Radar Rings with Splick Logo in center
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: 0x5B6CFF), Color(hex: 0x4ECDC4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: CGFloat(94 + i * 38), height: CGFloat(94 + i * 38))
                        .scaleEffect(wavePulse ? 1.15 : 0.9)
                        .opacity(wavePulse ? (0.7 - Double(i) * 0.2) : 0.2)
                        .animation(
                            .easeInOut(duration: 1.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.25),
                            value: wavePulse
                        )
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x5B6CFF), Color(hex: 0x4ECDC4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                    .shadow(color: Color(hex: 0x4ECDC4).opacity(0.65), radius: 22)

                Image("SplickLogoMark")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 44, height: 56)
                    .shadow(color: Color(hex: 0x00F5D4).opacity(0.9), radius: 10)
            }
            .frame(height: 180)
            .padding(.top, 16)

            VStack(spacing: 8) {
                Text("Sẵn sàng chạm NFC")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? .white : Color(hex: 0x0F172A))

                Text("Chạm mặt lưng iPhone vào thẻ NFC để mở hồ sơ kết bạn tức thì.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.65) : Color(hex: 0x64748B))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .padding(32)
        .frame(maxWidth: 360)
        .glassCardStyle()
        .onAppear {
            wavePulse = true
        }
    }
}

// MARK: - Loading Skeleton (Adaptive)

private struct LoadingCardSkeletonView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        VStack(spacing: 26) {
            // Skeleton Avatar
            ZStack {
                Circle()
                    .fill(shimmerFill)
                    .frame(width: 104, height: 104)

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x5B6CFF).opacity(colorScheme == .dark ? 0.6 : 0.4),
                                Color(hex: 0x4ECDC4).opacity(colorScheme == .dark ? 0.4 : 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 112, height: 112)
            }

            // Skeleton Name & Username
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(shimmerFill)
                    .frame(width: 170, height: 22)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(shimmerFill)
                    .frame(width: 110, height: 14)
            }

            // Skeleton Stats
            HStack(spacing: 36) {
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6).fill(shimmerFill).frame(width: 48, height: 20)
                    RoundedRectangle(cornerRadius: 4).fill(shimmerFill).frame(width: 60, height: 12)
                }
                Rectangle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color(hex: 0xCBD5E1))
                    .frame(width: 1, height: 32)
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6).fill(shimmerFill).frame(width: 48, height: 20)
                    RoundedRectangle(cornerRadius: 4).fill(shimmerFill).frame(width: 60, height: 12)
                }
            }
            .padding(.vertical, 6)

            // Skeleton Button
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(shimmerFill)
                .frame(height: 54)
                .padding(.horizontal, 12)
        }
        .padding(30)
        .frame(maxWidth: 360)
        .glassCardStyle()
        .onAppear {
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.0
            }
        }
    }

    private var shimmerFill: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.06), location: 0),
                    .init(color: .white.opacity(0.24), location: 0.5),
                    .init(color: .white.opacity(0.06), location: 1)
                ],
                startPoint: .init(x: -1.2 + shimmerPhase * 3.2, y: 0.3),
                endPoint: .init(x: -0.2 + shimmerPhase * 3.2, y: 0.7)
            )
        } else {
            return LinearGradient(
                stops: [
                    .init(color: Color(hex: 0xE2E8F0).opacity(0.55), location: 0),
                    .init(color: Color(hex: 0xF8FAFC), location: 0.5),
                    .init(color: Color(hex: 0xE2E8F0).opacity(0.55), location: 1)
                ],
                startPoint: .init(x: -1.2 + shimmerPhase * 3.2, y: 0.3),
                endPoint: .init(x: -0.2 + shimmerPhase * 3.2, y: 0.7)
            )
        }
    }
}

// MARK: - Loaded Profile Card Content (Adaptive)

private struct LoadedProfileCardContent: View {
    let profile: ClipPublicProfileDTO
    let viewModel: ClipInviteViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var avatarGlow: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            // 3D Glowing Avatar
            ZStack {
                // Background radial aura
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: 0x5B6CFF).opacity(colorScheme == .dark ? 0.55 : 0.25),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 75
                        )
                    )
                    .frame(width: 150, height: 150)
                    .scaleEffect(avatarGlow ? 1.08 : 0.95)

                // Avatar Image
                AsyncImage(url: profile.avatarUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure, .empty:
                        AvatarInitialsView(name: profile.displayName)
                    @unknown default:
                        AvatarInitialsView(name: profile.displayName)
                    }
                }
                .frame(width: 104, height: 104)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(hex: 0x4ECDC4), Color(hex: 0x5B6CFF), Color(hex: 0xE056FD)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(
                    color: colorScheme == .dark
                        ? Color(hex: 0x4ECDC4).opacity(0.4)
                        : Color(hex: 0x5B6CFF).opacity(0.25),
                    radius: 18,
                    y: 6
                )
            }
            .padding(.top, 4)

            // Name & Username
            VStack(spacing: 6) {
                Text(profile.displayName)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? .white : Color(hex: 0x0F172A))
                    .multilineTextAlignment(.center)

                HStack(spacing: 4) {
                    Text("@\(profile.username)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? Color(hex: 0x00F5D4) : Color(hex: 0x0D9488))

                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(colorScheme == .dark ? Color(hex: 0x00F5D4) : Color(hex: 0x0D9488))
                }
            }

            // Stats Pill Row
            HStack(spacing: 36) {
                StatPillItem(value: profile.friendCount, label: "bạn bè")

                Rectangle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.14) : Color(hex: 0xCBD5E1))
                    .frame(width: 1, height: 32)

                StatPillItem(value: profile.postCount, label: "bài viết")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                colorScheme == .dark
                    ? Color.white.opacity(0.04)
                    : Color(hex: 0xF1F5F9),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )

            // Action CTA Button
            ActionFriendButton(
                friendStatus: profile.friendStatus,
                isLoading: viewModel.isInviting
            ) {
                triggerHaptic()
                viewModel.sendInvite()
            }
            .padding(.horizontal, 6)

            // Open Full App Link
            Button {
                triggerHaptic()
                viewModel.openFullApp(username: profile.username)
            } label: {
                HStack(spacing: 4) {
                    Text("Mở hồ sơ trên Splick")
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color(hex: 0x4B5563))
            }
            .padding(.bottom, 2)

            // Brand Footer Tagline
            HStack(spacing: 5) {
                Image("SplickLogoMark")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 12, height: 16)
                    .opacity(0.65)
                Text("Splick • Click and Split")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.42) : Color(hex: 0x64748B))
            }
        }
        .padding(28)
        .frame(maxWidth: 360)
        .glassCardStyle()
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                avatarGlow = true
            }
        }
    }

    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Action Button (Adaptive)

private struct ActionFriendButton: View {
    let friendStatus: String?
    let isLoading: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var config: (label: String, icon: String, enabled: Bool, isPrimary: Bool) {
        switch friendStatus {
        case "FRIENDS":
            return ("Đã là bạn bè", "person.2.fill", false, false)
        case "PENDING":
            return ("Đang chờ phản hồi", "clock.badge.checkmark.fill", false, false)
        default:
            return ("Kết bạn ngay", "person.badge.plus.fill", true, true)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: config.icon)
                        .font(.system(.body, weight: .bold))
                    Text(config.label)
                        .font(.system(.body, design: .rounded, weight: .bold))
                }
            }
            .foregroundStyle(
                config.isPrimary
                    ? .white
                    : (colorScheme == .dark ? .white : Color(hex: 0x334155))
            )
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                if config.isPrimary {
                    LinearGradient(
                        colors: [Color(hex: 0x5B6CFF), Color(hex: 0x4ECDC4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color(hex: 0xF1F5F9)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        config.isPrimary
                            ? Color.white.opacity(0.35)
                            : (colorScheme == .dark ? Color.white.opacity(0.12) : Color(hex: 0xE2E8F0)),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: config.isPrimary
                    ? Color(hex: 0x5B6CFF).opacity(colorScheme == .dark ? 0.45 : 0.3)
                    : .clear,
                radius: 14,
                y: 5
            )
        }
        .disabled(!config.enabled || isLoading)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isLoading)
    }
}

// MARK: - Invite Sent Success Card (Adaptive)

private struct InviteSuccessCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var bounce: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x5B6CFF), Color(hex: 0x4ECDC4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: Color(hex: 0x4ECDC4).opacity(0.6), radius: 24)
                    .scaleEffect(bounce ? 1.0 : 0.5)

                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(.white)
                    .scaleEffect(bounce ? 1.0 : 0.3)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                Text("Đã gửi lời mời!")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? .white : Color(hex: 0x0F172A))

                Text("Lời mời kết bạn đã được chuyển đi thành công qua Splick.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.65) : Color(hex: 0x64748B))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: 360)
        .glassCardStyle()
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                bounce = true
            }
        }
    }
}

// MARK: - Error Card with Retry Button (Adaptive)

private struct ErrorCardView: View {
    let message: String
    let onRetry: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var errorPulse: Bool = false

    var body: some View {
        VStack(spacing: 22) {
            // Floating 3D Warning Icon
            ZStack {
                Circle()
                    .fill(Color(hex: 0xFF4757).opacity(errorPulse ? 0.25 : 0.12))
                    .frame(width: 84, height: 84)
                    .scaleEffect(errorPulse ? 1.1 : 0.95)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xFF6B81), Color(hex: 0xFF4757)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 66, height: 66)
                    .shadow(color: Color(hex: 0xFF4757).opacity(0.5), radius: 16)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                Text("Không thể tải thông tin")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? .white : Color(hex: 0x0F172A))

                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : Color(hex: 0x64748B))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            // Action: Retry Button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onRetry()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(.callout, weight: .bold))
                    Text("Thử lại")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                }
                .foregroundStyle(colorScheme == .dark ? .white : Color(hex: 0x0F172A))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    colorScheme == .dark
                        ? Color.white.opacity(0.12)
                        : Color(hex: 0xF1F5F9)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            colorScheme == .dark ? Color.white.opacity(0.2) : Color(hex: 0xCBD5E1),
                            lineWidth: 1
                        )
                )
            }
            .padding(.horizontal, 16)
        }
        .padding(28)
        .frame(maxWidth: 360)
        .glassCardStyle()
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                errorPulse = true
            }
        }
    }
}

// MARK: - Reusable Helpers (Adaptive)

private struct StatPillItem: View {
    let value: Int
    let label: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 2) {
            Text(formatCount(value))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? .white : Color(hex: 0x0F172A))

            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color(hex: 0x64748B))
        }
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

private struct AvatarInitialsView: View {
    let name: String

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x5B6CFF), Color(hex: 0x4ECDC4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image("SplickLogoMark")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 64, height: 84)
                .opacity(0.18)

            Text(initials)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Glass Card Modifier (Adaptive)

private struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)

                    // Subtle luxury Splick brand watermark in card background
                    Image("SplickLogoMark")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 150, height: 200)
                        .opacity(colorScheme == .dark ? 0.06 : 0.05)
                        .rotationEffect(.degrees(12))
                        .offset(x: 35, y: -25)
                        .blendMode(colorScheme == .dark ? .overlay : .multiply)
                }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(
                                        color: colorScheme == .dark ? .white.opacity(0.4) : .white.opacity(0.9),
                                        location: 0
                                    ),
                                    .init(
                                        color: colorScheme == .dark ? .white.opacity(0.08) : Color(hex: 0xCBD5E1).opacity(0.4),
                                        location: 0.4
                                    ),
                                    .init(
                                        color: Color(hex: 0x4ECDC4).opacity(colorScheme == .dark ? 0.3 : 0.35),
                                        location: 0.8
                                    ),
                                    .init(
                                        color: Color(hex: 0x5B6CFF).opacity(colorScheme == .dark ? 0.25 : 0.3),
                                        location: 1
                                    )
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
            }
            .shadow(
                color: colorScheme == .dark
                    ? .black.opacity(0.45)
                    : Color(hex: 0x0F172A).opacity(0.08),
                radius: colorScheme == .dark ? 32 : 24,
                y: colorScheme == .dark ? 16 : 10
            )
            .shadow(
                color: Color(hex: 0x5B6CFF).opacity(colorScheme == .dark ? 0.2 : 0.1),
                radius: 20,
                y: 6
            )
            .padding(.horizontal, 20)
    }
}

private extension View {
    func glassCardStyle() -> some View {
        modifier(GlassCardModifier())
    }
}

// MARK: - Math & Color Utilities

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

private extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Xcode Previews (Both Light & Dark)

#Preview("Dark Mode — Loaded") {
    let vm = ClipInviteViewModel()
    vm.state = .loaded(ClipPublicProfileDTO(
        userId: "abc",
        username: "hoan03",
        displayName: "Hoàn Trần",
        avatarUrl: nil,
        friendCount: 348,
        postCount: 42,
        friendStatus: "NONE"
    ))
    return ProfileCardView()
        .environmentObject(vm)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode — Loaded") {
    let vm = ClipInviteViewModel()
    vm.state = .loaded(ClipPublicProfileDTO(
        userId: "abc",
        username: "hoan03",
        displayName: "Hoàn Trần",
        avatarUrl: nil,
        friendCount: 348,
        postCount: 42,
        friendStatus: "NONE"
    ))
    return ProfileCardView()
        .environmentObject(vm)
        .preferredColorScheme(.light)
}

#Preview("Light Mode — Skeleton") {
    let vm = ClipInviteViewModel()
    vm.state = .loading
    return ProfileCardView()
        .environmentObject(vm)
        .preferredColorScheme(.light)
}

#Preview("Light Mode — Error Retry") {
    let vm = ClipInviteViewModel()
    vm.state = .error("Không thể kết nối đến máy chủ. Vui lòng thử lại.")
    return ProfileCardView()
        .environmentObject(vm)
        .preferredColorScheme(.light)
}
