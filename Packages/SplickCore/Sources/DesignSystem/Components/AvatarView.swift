import SwiftUI
import Common

public struct AvatarView: View {
    public enum Size {
        case small, medium, large, profile

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 48
            case .large: return 72
            case .profile: return 96
            }
        }

        var fontSize: Font {
            switch self {
            case .small: return .caption
            case .medium: return .body
            case .large, .profile: return .title2
            }
        }
    }

    private let imageURL: URL?
    private let userId: UUID?
    private let displayName: String
    private let initials: String
    private let size: Size

    public init(imageURL: URL? = nil, name: String, size: Size = .medium, userId: UUID? = nil) {
        self.imageURL = imageURL
        self.userId = userId
        self.displayName = name
        self.size = size
        self.initials = String(name.prefix(2)).uppercased()
    }

    public var body: some View {
        Group {
            if SplickBot.isBot(userId) {
                Image("SplickBotAvatar", bundle: .module)
                    .resizable()
                    .scaledToFill()
            } else if DeletedUser.isDeleted(displayName: displayName) && imageURL == nil {
                Image("DeletedUserAvatar", bundle: .module)
                    .resizable()
                    .scaledToFill()
            } else if let imageURL {
                RemoteImage(
                    url: imageURL,
                    maxPixelSize: RemoteImageMetrics.avatarMaxPixelWidth(pointSize: size.dimension)
                ) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        initialsView
                    default:
                        ProgressView()
                            .controlSize(loadingControlSize)
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(Circle())
    }

    private var loadingControlSize: ControlSize {
        switch size {
        case .small: return .mini
        case .medium: return .small
        case .large, .profile: return .regular
        }
    }

    private var initialsView: some View {
        ZStack {
            SplickTheme.Colors.primaryGradient
            Text(initials)
                .font(size.fontSize)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }
}
