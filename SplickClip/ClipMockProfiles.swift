//
//  ClipMockProfiles.swift
//  SplickClip
//
//  Local mock profiles for App Clip demo / NFC testing before public API ships.
//  Primary demo URL: https://splick.app/tq.hoan03
//

import Foundation

// MARK: - Extended profile fields (Clip-local)

struct ClipProfileBadge: Hashable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    /// Brand accent hex without `#`
    let accentHex: UInt
}

struct ClipProfileHighlight: Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
}

struct ClipRecentSplit: Hashable, Sendable {
    let title: String
    let people: Int
    let amount: String
    let timeAgo: String
}

struct ClipMutualFriend: Hashable, Sendable {
    let initials: String
    let accentHex: UInt
}

struct ClipRichProfile: Sendable {
    let dto: ClipPublicProfileDTO
    let bio: String
    let location: String
    let memberSince: String
    let profileURL: String
    let isVerified: Bool
    let isOnline: Bool
    let vibe: String
    let rankTitle: String
    let quote: String
    let recentSplit: ClipRecentSplit
    let mutuals: [ClipMutualFriend]
    let mutualCount: Int
    let badges: [ClipProfileBadge]
    let highlights: [ClipProfileHighlight]
}

enum ClipMockProfiles {
    static let demoUsername = "tq.hoan03"
    /// Canonical demo invitation link for NFC / Simulator.
    static let demoInviteURL = URL(string: "https://splick.app/tq.hoan03")!

    static let tqHoan03 = ClipRichProfile(
        dto: ClipPublicProfileDTO(
            userId: "00000000-0000-0000-0000-00000000h03a",
            username: "tq.hoan03",
            displayName: "Hoàn Trần",
            avatarUrl: URL(string: "https://i.pravatar.cc/400?u=tq.hoan03"),
            friendCount: 1_284,
            postCount: 96,
            friendStatus: "NONE"
        ),
        bio: "Founder @ Splick · Click and Split ✨\nChia bill nhanh — kết bạn nhanh hơn.",
        location: "Hà Nội, Việt Nam",
        memberSince: "Thành viên từ 2024",
        profileURL: "splick.app/tq.hoan03",
        isVerified: true,
        isOnline: true,
        vibe: "Night owl · Café hop",
        rankTitle: "TOP SPLITTER",
        quote: "Life’s better when the bill is fair.",
        recentSplit: ClipRecentSplit(
            title: "Ramen midnight",
            people: 4,
            amount: "₫860K",
            timeAgo: "2 giờ trước"
        ),
        mutuals: [
            ClipMutualFriend(initials: "LN", accentHex: 0x5B6CFF),
            ClipMutualFriend(initials: "MT", accentHex: 0x4ECDC4),
            ClipMutualFriend(initials: "ĐN", accentHex: 0xE056FD)
        ],
        mutualCount: 12,
        badges: [
            ClipProfileBadge(id: "founder", title: "Founder", systemImage: "crown.fill", accentHex: 0xF59E0B),
            ClipProfileBadge(id: "splitter", title: "Pro Splitter", systemImage: "bolt.fill", accentHex: 0x5B6CFF),
            ClipProfileBadge(id: "streak", title: "Streak 21", systemImage: "flame.fill", accentHex: 0xFF6B4A),
            ClipProfileBadge(id: "trusted", title: "Trusted", systemImage: "checkmark.seal.fill", accentHex: 0x4ECDC4)
        ],
        highlights: [
            ClipProfileHighlight(
                id: "bills",
                title: "₫48.2M",
                subtitle: "đã chia tháng này",
                systemImage: "chart.bar.fill"
            ),
            ClipProfileHighlight(
                id: "groups",
                title: "18 nhóm",
                subtitle: "đang hoạt động",
                systemImage: "person.3.fill"
            ),
            ClipProfileHighlight(
                id: "settle",
                title: "99%",
                subtitle: "settle đúng hạn",
                systemImage: "sparkles"
            )
        ]
    )

    static func richProfile(for username: String) -> ClipRichProfile? {
        switch username.lowercased() {
        case "tq.hoan03", "hoan03", "tqhoan03":
            return tqHoan03
        default:
            return nil
        }
    }

    static func dto(for username: String) -> ClipPublicProfileDTO? {
        richProfile(for: username)?.dto
    }
}
