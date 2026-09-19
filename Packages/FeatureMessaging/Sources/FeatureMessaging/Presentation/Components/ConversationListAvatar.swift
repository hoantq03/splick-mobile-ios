import SwiftUI
import DesignSystem

/// Inbox avatar: 48×48 layout. Online / recent last-seen overlay the bottom-trailing
/// corner and overlap the photo slightly — they must not grow the row.
struct ConversationListAvatar: View {
    let imageURL: URL?
    let name: String
    var userId: UUID? = nil
    var isOnline: Bool = false
    var lastSeenLabel: String? = nil

    private static let avatarSize: CGFloat = 48
    private static let onlineDotSize: CGFloat = 14
    private static let lastSeenHeight: CGFloat = 14

    var body: some View {
        AvatarView(imageURL: imageURL, name: name, size: .medium, userId: userId)
            .overlay(alignment: .bottomTrailing) {
                presenceBadge
                    .offset(x: 1, y: 1)
            }
            .frame(width: Self.avatarSize, height: Self.avatarSize)
    }

    @ViewBuilder
    private var presenceBadge: some View {
        if isOnline {
            Circle()
                .fill(SplickTheme.Colors.success)
                .frame(width: Self.onlineDotSize, height: Self.onlineDotSize)
                .overlay {
                    Circle()
                        .strokeBorder(SplickTheme.Colors.background, lineWidth: 2)
                }
        } else if let lastSeenLabel, !lastSeenLabel.isEmpty {
            Text(lastSeenLabel)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 4)
                .frame(height: Self.lastSeenHeight)
                .frame(maxWidth: 28)
                .background(SplickTheme.Colors.success, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(SplickTheme.Colors.background, lineWidth: 2)
                }
        }
    }
}
