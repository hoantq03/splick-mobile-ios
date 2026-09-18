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
                        IdleScanCardView {
                            viewModel.loadDemoProfile()
                        }
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
                        LoadedProfileCardContent(
                            profile: profile,
                            rich: viewModel.richProfile,
                            viewModel: viewModel
                        )
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
                Color(hex: 0x05050C).ignoresSafeArea()

                Circle()
                    .fill(Color(hex: 0x5B6CFF).opacity(pulse ? 0.42 : 0.26))
                    .frame(width: 340, height: 340)
                    .blur(radius: 90)
                    .offset(x: pulse ? -90 : -40, y: pulse ? -160 : -110)

                Circle()
                    .fill(Color(hex: 0x00F5D4).opacity(pulse ? 0.32 : 0.18))
                    .frame(width: 300, height: 300)
                    .blur(radius: 82)
                    .offset(x: pulse ? 100 : 50, y: pulse ? 140 : 90)

                Circle()
                    .fill(Color(hex: 0xE056FD).opacity(pulse ? 0.22 : 0.12))
                    .frame(width: 220, height: 220)
                    .blur(radius: 70)
                    .offset(x: pulse ? 20 : -30, y: pulse ? 40 : 80)
            } else {
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

                Circle()
                    .fill(Color(hex: 0x5B6CFF).opacity(pulse ? 0.20 : 0.10))
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)
                    .offset(x: pulse ? -70 : -40, y: pulse ? -120 : -90)

                Circle()
                    .fill(Color(hex: 0x4ECDC4).opacity(pulse ? 0.22 : 0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 70)
                    .offset(x: pulse ? 80 : 50, y: pulse ? 110 : 70)

                Circle()
                    .fill(Color(hex: 0xE056FD).opacity(pulse ? 0.12 : 0.06))
                    .frame(width: 200, height: 200)
                    .blur(radius: 60)
                    .offset(x: pulse ? -10 : 30, y: pulse ? 20 : -20)
            }

            StarfieldView(isDark: colorScheme == .dark)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }
}

private struct StarfieldView: View {
    let isDark: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for i in 0..<28 {
                    let seed = Double(i * 47)
                    let x = (sin(seed) * 0.5 + 0.5) * size.width
                    let y = (cos(seed * 1.3) * 0.5 + 0.5) * size.height
                    let twinkle = (sin(t * (1.4 + Double(i % 5) * 0.35) + seed) * 0.5 + 0.5)
                    let radius = isDark ? (0.7 + twinkle * 1.6) : (0.5 + twinkle * 1.1)
                    let rect = CGRect(x: x, y: y, width: radius, height: radius)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(
                            Color.white.opacity(isDark ? 0.18 + twinkle * 0.55 : 0.08 + twinkle * 0.22)
                        )
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 18, height: 14)

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
    var onPreviewDemo: () -> Void
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
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 44, height: 35)
                    .foregroundStyle(.white)
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

            // Mock invite URL pill — tap to preview demo profile
            Button(action: onPreviewDemo) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .bold))
                    Text(ClipMockProfiles.demoInviteURL.absoluteString.replacingOccurrences(of: "https://", with: ""))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(colorScheme == .dark ? Color(hex: 0x00F5D4) : Color(hex: 0x0D9488))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    (colorScheme == .dark ? Color(hex: 0x00F5D4).opacity(0.12) : Color(hex: 0x0D9488).opacity(0.1)),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(
                        (colorScheme == .dark ? Color(hex: 0x00F5D4) : Color(hex: 0x0D9488)).opacity(0.35),
                        lineWidth: 1
                    )
                )
            }
            .buttonStyle(.plain)
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
    let rich: ClipRichProfile?
    let viewModel: ClipInviteViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var avatarGlow: Bool = false
    @State private var contentReveal: Bool = false
    @State private var displayedFriends: Int = 0
    @State private var displayedPosts: Int = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                if let rank = rich?.rankTitle {
                    RankRibbon(title: rank)
                        .padding(.top, 2)
                }

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: 0x5B6CFF).opacity(colorScheme == .dark ? 0.62 : 0.28),
                                    Color(hex: 0xE056FD).opacity(colorScheme == .dark ? 0.18 : 0.08),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 12,
                                endRadius: 82
                            )
                        )
                        .frame(width: 164, height: 164)
                        .scaleEffect(avatarGlow ? 1.1 : 0.94)

                    AvatarSparklesView()

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
                        TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { timeline in
                            let degrees = timeline.date.timeIntervalSinceReferenceDate * 40
                            Circle()
                                .strokeBorder(
                                    AngularGradient(
                                        colors: [
                                            Color(hex: 0x4ECDC4),
                                            Color(hex: 0x5B6CFF),
                                            Color(hex: 0xE056FD),
                                            Color(hex: 0xF59E0B),
                                            Color(hex: 0x4ECDC4)
                                        ],
                                        center: .center
                                    ),
                                    lineWidth: 3.2
                                )
                                .rotationEffect(.degrees(degrees))
                        }
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? Color(hex: 0x4ECDC4).opacity(0.5)
                            : Color(hex: 0x5B6CFF).opacity(0.28),
                        radius: 18,
                        y: 6
                    )

                    if rich?.isOnline == true {
                        OnlinePulseDot()
                            .offset(x: 38, y: 38)
                    }
                }
                .padding(.top, 2)

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text(profile.displayName)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(holographicName)

                        if rich?.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: 0x5B6CFF), Color(hex: 0x4ECDC4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color(hex: 0x5B6CFF).opacity(0.45), radius: 4)
                        }
                    }

                    Text("@\(profile.username)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? Color(hex: 0x00F5D4) : Color(hex: 0x0D9488))

                    if let rich {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10, weight: .semibold))
                            Text(rich.location)
                            Text("·")
                            Text(rich.vibe)
                        }
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.48) : Color(hex: 0x64748B))
                    }
                }
                .opacity(contentReveal ? 1 : 0)
                .offset(y: contentReveal ? 0 : 8)

                if let quote = rich?.quote {
                    Text("“\(quote)”")
                        .font(.system(.caption, design: .serif).italic())
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.78) : Color(hex: 0x334155))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                        .opacity(contentReveal ? 1 : 0)
                }

                if let bio = rich?.bio {
                    Text(bio)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.68) : Color(hex: 0x475569))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 8)
                        .opacity(contentReveal ? 1 : 0)
                }

                if let url = rich?.profileURL {
                    ProfileURLPill(urlText: url)
                        .opacity(contentReveal ? 1 : 0)
                }

                if let badges = rich?.badges, !badges.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(badges, id: \.id) { badge in
                                BadgeChipView(badge: badge)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .opacity(contentReveal ? 1 : 0)
                }

                HStack(spacing: 0) {
                    StatPillItem(value: displayedFriends, label: "bạn bè")
                        .frame(maxWidth: .infinity)
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.14) : Color(hex: 0xCBD5E1))
                        .frame(width: 1, height: 32)
                    StatPillItem(value: displayedPosts, label: "bài viết")
                        .frame(maxWidth: .infinity)
                    if let mutualCount = rich?.mutualCount {
                        Rectangle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.14) : Color(hex: 0xCBD5E1))
                            .frame(width: 1, height: 32)
                        StatPillItem(value: mutualCount, label: "chung")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                .background(
                    colorScheme == .dark
                        ? Color.white.opacity(0.045)
                        : Color(hex: 0xF1F5F9),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .opacity(contentReveal ? 1 : 0)

                if let rich {
                    MutualRow(friends: rich.mutuals, extraCount: max(0, rich.mutualCount - rich.mutuals.count))
                        .opacity(contentReveal ? 1 : 0)

                    RecentSplitRow(split: rich.recentSplit)
                        .opacity(contentReveal ? 1 : 0)
                }

                if let highlights = rich?.highlights, !highlights.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(highlights, id: \.id) { item in
                            HighlightMiniCard(item: item)
                        }
                    }
                    .opacity(contentReveal ? 1 : 0)
                }

                ActionFriendButton(
                    friendStatus: profile.friendStatus,
                    isLoading: viewModel.isInviting
                ) {
                    triggerHaptic()
                    viewModel.sendInvite()
                }
                .padding(.horizontal, 2)

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

                HStack(spacing: 5) {
                    Image("SplickLogoMark")
                        .resizable()
                        .interpolation(.high)
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 12, height: 10)
                        .opacity(0.9)
                    Text("Splick • Click and Split")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.42) : Color(hex: 0x64748B))
                }
                .padding(.bottom, 4)
            }
            .padding(22)
        }
        .frame(maxWidth: 360)
        .frame(maxHeight: 640)
        .glassCardStyle()
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                avatarGlow = true
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.08)) {
                contentReveal = true
            }
            animateCounts()
        }
    }

    private var holographicName: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.white, Color(hex: 0xA5B4FC), Color(hex: 0x4ECDC4)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [Color(hex: 0x0F172A), Color(hex: 0x4338CA), Color(hex: 0x0D9488)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func animateCounts() {
        displayedFriends = 0
        displayedPosts = 0
        let friends = profile.friendCount
        let posts = profile.postCount
        Task { @MainActor in
            for step in 1...18 {
                try? await Task.sleep(nanoseconds: 28_000_000)
                let progress = Double(step) / 18.0
                displayedFriends = Int(Double(friends) * progress)
                displayedPosts = Int(Double(posts) * progress)
            }
            displayedFriends = friends
            displayedPosts = posts
        }
    }

    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Fancy Profile Subviews

private struct AvatarSparklesView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    let angle = (Double(i) / 8.0) * .pi * 2 + t * 0.9
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x00F5D4), Color(hex: 0xE056FD)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: i.isMultiple(of: 2) ? 6 : 3.5, height: i.isMultiple(of: 2) ? 6 : 3.5)
                        .blur(radius: 0.3)
                        .shadow(color: Color(hex: 0x4ECDC4).opacity(0.85), radius: 4)
                        .offset(x: cos(angle) * 70, y: sin(angle) * 70)
                        .opacity(0.55 + 0.4 * sin(t * 2 + Double(i)))
                }
            }
            .frame(width: 160, height: 160)
        }
        .allowsHitTesting(false)
    }
}

private struct ProfileURLPill: View {
    let urlText: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "link")
                .font(.system(size: 10, weight: .bold))
            Text(urlText)
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
        }
        .foregroundStyle(colorScheme == .dark ? Color(hex: 0xA5B4FC) : Color(hex: 0x4F46E5))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            (colorScheme == .dark ? Color(hex: 0x5B6CFF).opacity(0.16) : Color(hex: 0xEEF2FF)),
            in: Capsule()
        )
        .overlay(
            Capsule().strokeBorder(
                Color(hex: 0x5B6CFF).opacity(colorScheme == .dark ? 0.35 : 0.22),
                lineWidth: 1
            )
        )
    }
}

private struct BadgeChipView: View {
    let badge: ClipProfileBadge
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: badge.systemImage)
                .font(.system(size: 10, weight: .bold))
            Text(badge.title)
                .font(.system(.caption2, design: .rounded, weight: .bold))
        }
        .foregroundStyle(Color(hex: badge.accentHex))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Color(hex: badge.accentHex).opacity(colorScheme == .dark ? 0.18 : 0.12),
            in: Capsule()
        )
        .overlay(
            Capsule().strokeBorder(Color(hex: badge.accentHex).opacity(0.35), lineWidth: 1)
        )
    }
}

private struct HighlightMiniCard: View {
    let item: ClipProfileHighlight
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(hex: 0x4ECDC4))
                Text(item.title)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? .white : Color(hex: 0x0F172A))
                    .lineLimit(1)
            }
            Text(item.subtitle)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.45) : Color(hex: 0x64748B))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            colorScheme == .dark ? Color.white.opacity(0.05) : Color(hex: 0xF8FAFC),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x4ECDC4).opacity(0.45),
                            Color(hex: 0x5B6CFF).opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

private struct RankRibbon: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .bold))
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.4)
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(
            LinearGradient(
                colors: [Color(hex: 0xFDE68A), Color(hex: 0xF59E0B), Color(hex: 0xFDE68A)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color(hex: 0xF59E0B).opacity(0.16))
        )
        .overlay(
            Capsule().strokeBorder(Color(hex: 0xF59E0B).opacity(0.45), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0xF59E0B).opacity(0.28), radius: 8, y: 2)
    }
}

private struct OnlinePulseDot: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x22C55E).opacity(0.28))
                .frame(width: pulse ? 22 : 16, height: pulse ? 22 : 16)
            Circle()
                .fill(Color(hex: 0x22C55E))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct MutualRow: View {
    let friends: [ClipMutualFriend]
    let extraCount: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: -8) {
                ForEach(friends, id: \.initials) { friend in
                    Text(friend.initials)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color(hex: friend.accentHex)))
                        .overlay(Circle().stroke(colorScheme == .dark ? Color(hex: 0x0A0A14) : .white, lineWidth: 1.5))
                }
            }

            Text(extraCount > 0 ? "+\(extraCount) bạn chung" : "Bạn chung")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.62) : Color(hex: 0x475569))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            colorScheme == .dark ? Color.white.opacity(0.04) : Color(hex: 0xF8FAFC),
            in: Capsule()
        )
    }
}

private struct RecentSplitRow: View {
    let split: ClipRecentSplit
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x5B6CFF), Color(hex: 0x4ECDC4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: "fork.knife")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(split.title)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? .white : Color(hex: 0x0F172A))
                Text("\(split.people) người · \(split.timeAgo)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.45) : Color(hex: 0x64748B))
            }

            Spacer(minLength: 0)

            Text(split.amount)
                .font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(colorScheme == .dark ? Color(hex: 0x00F5D4) : Color(hex: 0x0D9488))
        }
        .padding(10)
        .background(
            colorScheme == .dark ? Color.white.opacity(0.05) : Color(hex: 0xF8FAFC),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: 0x5B6CFF).opacity(0.4), Color(hex: 0x4ECDC4).opacity(0.35)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
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
                    ZStack {
                        LinearGradient(
                            colors: [Color(hex: 0x5B6CFF), Color(hex: 0x4ECDC4), Color(hex: 0xE056FD)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        TimelineView(.animation(minimumInterval: 1 / 24, paused: false)) { timeline in
                            let t = timeline.date.timeIntervalSinceReferenceDate
                            let x = CGFloat((sin(t * 1.4) * 0.5) + 0.5)
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: max(0, x - 0.22)),
                                    .init(color: .white.opacity(0.38), location: x),
                                    .init(color: .clear, location: min(1, x + 0.22))
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
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
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 64, height: 51)
                .foregroundStyle(.white)
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
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 150, height: 119)
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color(hex: 0x0F172A))
                        .opacity(colorScheme == .dark ? 0.06 : 0.05)
                        .rotationEffect(.degrees(12))
                        .offset(x: 35, y: -25)
                        .blendMode(colorScheme == .dark ? .overlay : .multiply)
                }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay {
                    TimelineView(.animation(minimumInterval: 1 / 24, paused: false)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let x = (sin(t * 0.7) * 0.55) + 0.15
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white.opacity(colorScheme == .dark ? 0.14 : 0.22), location: x),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.overlay)
                    }
                    .allowsHitTesting(false)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(
                                        color: colorScheme == .dark ? .white.opacity(0.5) : .white.opacity(0.95),
                                        location: 0
                                    ),
                                    .init(
                                        color: colorScheme == .dark ? .white.opacity(0.08) : Color(hex: 0xCBD5E1).opacity(0.4),
                                        location: 0.35
                                    ),
                                    .init(
                                        color: Color(hex: 0x4ECDC4).opacity(colorScheme == .dark ? 0.45 : 0.4),
                                        location: 0.7
                                    ),
                                    .init(
                                        color: Color(hex: 0xE056FD).opacity(colorScheme == .dark ? 0.35 : 0.28),
                                        location: 1
                                    )
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.4
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
    let mock = ClipMockProfiles.tqHoan03
    vm.richProfile = mock
    vm.state = .loaded(mock.dto)
    return ProfileCardView()
        .environmentObject(vm)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode — Loaded") {
    let vm = ClipInviteViewModel()
    let mock = ClipMockProfiles.tqHoan03
    vm.richProfile = mock
    vm.state = .loaded(mock.dto)
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
