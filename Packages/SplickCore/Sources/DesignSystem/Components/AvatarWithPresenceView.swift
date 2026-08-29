import SwiftUI
import Localization

public struct AvatarWithPresenceView: View {
    private let imageURL: URL?
    private let name: String
    private let size: AvatarView.Size
    private let userId: UUID?
    private let showOnlineIndicator: Bool
    private let lastSeenLabel: String?

    public init(
        imageURL: URL?,
        name: String,
        size: AvatarView.Size = .medium,
        userId: UUID? = nil,
        showOnlineIndicator: Bool = false,
        lastSeenLabel: String? = nil
    ) {
        self.imageURL = imageURL
        self.name = name
        self.size = size
        self.userId = userId
        self.showOnlineIndicator = showOnlineIndicator
        self.lastSeenLabel = lastSeenLabel
    }

    public var body: some View {
        AvatarView(imageURL: imageURL, name: name, size: size, userId: userId)
            .overlay(alignment: .bottomTrailing) {
                if showOnlineIndicator {
                    Circle()
                        .fill(SplickTheme.Colors.success)
                        .frame(width: badgeSize, height: badgeSize)
                        .overlay {
                            Circle()
                                .strokeBorder(SplickTheme.Colors.background, lineWidth: ringWidth)
                        }
                        .offset(x: 2, y: 2)
                } else if let lastSeenLabel, !lastSeenLabel.isEmpty {
                    Text(lastSeenLabel)
                        .font(.system(size: lastSeenFontSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 5)
                        .frame(minWidth: badgeSize, minHeight: badgeSize)
                        .background(SplickTheme.Colors.success, in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(SplickTheme.Colors.background, lineWidth: ringWidth)
                        }
                        .offset(x: 2, y: 2)
                }
            }
            .frame(width: size.dimension, height: size.dimension)
            .padding(6)
    }

    private var badgeSize: CGFloat {
        switch size {
        case .small: return 12
        case .medium: return 15
        case .large: return 18
        case .profile: return 20
        }
    }

    private var lastSeenFontSize: CGFloat {
        switch size {
        case .small: return 7
        case .medium: return 8
        case .large: return 9
        case .profile: return 10
        }
    }

    private var ringWidth: CGFloat { 2 }
}
