import SwiftUI

public struct AvatarWithPresenceView: View {
    private let imageURL: URL?
    private let name: String
    private let size: AvatarView.Size
    private let userId: UUID?
    private let showOnlineIndicator: Bool

    public init(
        imageURL: URL?,
        name: String,
        size: AvatarView.Size = .medium,
        userId: UUID? = nil,
        showOnlineIndicator: Bool = false
    ) {
        self.imageURL = imageURL
        self.name = name
        self.size = size
        self.userId = userId
        self.showOnlineIndicator = showOnlineIndicator
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarView(imageURL: imageURL, name: name, size: size, userId: userId)

            if showOnlineIndicator {
                Circle()
                    .fill(SplickTheme.Colors.success)
                    .frame(width: badgeSize, height: badgeSize)
                    .overlay {
                        Circle()
                            .strokeBorder(SplickTheme.Colors.background, lineWidth: ringWidth)
                    }
                    .offset(x: overhang, y: overhang)
            }
        }
        .frame(width: canvasSize, height: canvasSize)
    }

    private var canvasSize: CGFloat { size.dimension + overhang }
    private var badgeSize: CGFloat {
        switch size {
        case .small: return 10
        case .medium: return 12
        case .large: return 14
        }
    }

    private var ringWidth: CGFloat { 2 }
    private var overhang: CGFloat { 2 }
}
