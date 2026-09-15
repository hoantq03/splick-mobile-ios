//
//  ProfileCardView.swift
//  SplickClip
//

import SwiftUI

// MARK: - Root view

struct ProfileCardView: View {
    @EnvironmentObject var viewModel: ClipInviteViewModel

    var body: some View {
        ZStack {
            // Background gradient matching Splick brand
            LinearGradient(
                colors: [
                    Color(hex: 0x0F0F1A),
                    Color(hex: 0x1A1A2E),
                    Color(hex: 0x16213E)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Splick wordmark
                SplickBadge()
                    .padding(.top, 20)

                Spacer()

                // Card content
                switch viewModel.state {
                case .idle:
                    IdleView()
                case .loading:
                    LoadingCardView()
                case .loaded(let profile):
                    LoadedCardView(profile: profile, viewModel: viewModel)
                case .inviteSent:
                    InviteSentView()
                case .error(let message):
                    ErrorCardView(message: message)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Splick brand badge

private struct SplickBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x5B6CFF), Color(hex: 0x4ECDC4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 10, height: 10)
            Text("splick")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.08), in: Capsule())
    }
}

// MARK: - Idle

private struct IdleView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
            Text("Tap thẻ NFC để xem profile")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Loading skeleton

private struct LoadingCardView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Circle()
                .fill(shimmerGradient)
                .frame(width: 96, height: 96)

            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(shimmerGradient)
                    .frame(width: 160, height: 20)
                RoundedRectangle(cornerRadius: 6)
                    .fill(shimmerGradient)
                    .frame(width: 100, height: 14)
            }

            HStack(spacing: 32) {
                StatSkeletonView()
                StatSkeletonView()
            }

            RoundedRectangle(cornerRadius: 16)
                .fill(shimmerGradient)
                .frame(height: 52)
                .padding(.horizontal, 32)
        }
        .padding(32)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.06), location: 0),
                .init(color: .white.opacity(0.15), location: 0.5),
                .init(color: .white.opacity(0.06), location: 1)
            ],
            startPoint: .init(x: -1 + phase * 3, y: 0.5),
            endPoint: .init(x: phase * 3, y: 0.5)
        )
    }
}

private struct StatSkeletonView: View {
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.1)).frame(width: 40, height: 18)
            RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.06)).frame(width: 56, height: 12)
        }
    }
}

// MARK: - Loaded profile card

private struct LoadedCardView: View {
    let profile: ClipPublicProfileDTO
    let viewModel: ClipInviteViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                // Avatar
                AsyncImage(url: profile.avatarUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure, .empty:
                        AvatarPlaceholder(name: profile.displayName)
                    @unknown default:
                        AvatarPlaceholder(name: profile.displayName)
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(hex: 0x5B6CFF), Color(hex: 0x4ECDC4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                )
                .shadow(color: Color(hex: 0x5B6CFF).opacity(0.4), radius: 16, y: 6)

                // Name & username
                VStack(spacing: 4) {
                    Text(profile.displayName)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("@\(profile.username)")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                // Stats
                HStack(spacing: 40) {
                    StatPill(value: profile.friendCount, label: "bạn bè")
                    Rectangle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 1, height: 28)
                    StatPill(value: profile.postCount, label: "bài viết")
                }

                // CTA
                FriendActionButton(
                    friendStatus: profile.friendStatus,
                    isLoading: viewModel.isInviting
                ) {
                    viewModel.sendInvite()
                }

                // Open full app
                Button {
                    viewModel.openFullApp(username: profile.username)
                } label: {
                    Text("Mở Splick")
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .underline()
                }
            }
            .padding(28)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .shadow(color: .black.opacity(0.35), radius: 28, y: 12)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Stat pill

private struct StatPill: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(formatCount(value))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Avatar placeholder (initials)

private struct AvatarPlaceholder: View {
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
            Text(initials)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Friend action button

private struct FriendActionButton: View {
    let friendStatus: String?
    let isLoading: Bool
    let action: () -> Void

    private var config: (label: String, icon: String, enabled: Bool, isPrimary: Bool) {
        switch friendStatus {
        case "FRIENDS":
            return ("Đã là bạn bè", "checkmark.circle.fill", false, false)
        case "PENDING":
            return ("Đã gửi lời mời", "clock.fill", false, false)
        default:
            // nil (anonymous) or "NONE"
            return ("Kết bạn", "person.badge.plus", true, true)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: config.icon)
                        .font(.system(.callout, weight: .semibold))
                    Text(config.label)
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                if config.isPrimary {
                    LinearGradient(
                        colors: [Color(hex: 0x5B6CFF), Color(hex: 0x4ECDC4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    Color.white.opacity(0.08)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        config.isPrimary ? .clear : .white.opacity(0.12),
                        lineWidth: 1
                    )
            )
        }
        .disabled(!config.enabled || isLoading)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Invite sent

private struct InviteSentView: View {
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x5B6CFF), Color(hex: 0x4ECDC4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                    scale = 1; opacity = 1
                }
            }

            VStack(spacing: 6) {
                Text("Đã gửi lời mời kết bạn!")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("Khi họ chấp nhận, bạn sẽ trở thành bạn bè trên Splick.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }
}

// MARK: - Error

private struct ErrorCardView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: 0xEB5757))

            Text("Có lỗi xảy ra")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// MARK: - Color helper (inline — avoids importing DesignSystem to keep App Clip binary small)

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

// MARK: - Previews

#Preview("Idle") {
    ProfileCardView()
        .environmentObject(ClipInviteViewModel())
}

#Preview("Loaded — NONE") {
    let vm = ClipInviteViewModel()
    vm.state = .loaded(ClipPublicProfileDTO(
        userId: "abc",
        username: "hoan03",
        displayName: "Hoàn Trần",
        avatarUrl: nil,
        friendCount: 142,
        postCount: 38,
        friendStatus: "NONE"
    ))
    return ProfileCardView().environmentObject(vm)
}

#Preview("Loaded — FRIENDS") {
    let vm = ClipInviteViewModel()
    vm.state = .loaded(ClipPublicProfileDTO(
        userId: "abc",
        username: "hoan03",
        displayName: "Hoàn Trần",
        avatarUrl: nil,
        friendCount: 142,
        postCount: 38,
        friendStatus: "FRIENDS"
    ))
    return ProfileCardView().environmentObject(vm)
}

#Preview("Loading") {
    let vm = ClipInviteViewModel()
    vm.state = .loading
    return ProfileCardView().environmentObject(vm)
}

#Preview("Invite Sent") {
    let vm = ClipInviteViewModel()
    vm.state = .inviteSent
    return ProfileCardView().environmentObject(vm)
}
