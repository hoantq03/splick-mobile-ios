import SwiftUI

public struct AvatarView: View {
    public enum Size {
        case small, medium, large

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 48
            case .large: return 72
            }
        }

        var fontSize: Font {
            switch self {
            case .small: return .caption
            case .medium: return .body
            case .large: return .title2
            }
        }
    }

    private let imageURL: URL?
    private let initials: String
    private let size: Size

    public init(imageURL: URL? = nil, name: String, size: Size = .medium) {
        self.imageURL = imageURL
        self.size = size
        self.initials = String(name.prefix(2)).uppercased()
    }

    public var body: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        initialsView
                    default:
                        ProgressView()
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(Circle())
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
