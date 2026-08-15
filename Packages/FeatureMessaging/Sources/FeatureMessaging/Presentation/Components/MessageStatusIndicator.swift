import SwiftUI
import DesignSystem
import SplickDomain

struct MessageStatusIndicator: View {
    let status: MessageDeliveryStatus
    var showsReadAvatar: Bool = false
    var readAvatarURL: URL? = nil
    var readAvatarName: String = ""
    var readAvatarNamespace: Namespace.ID? = nil
    var conversationId: UUID? = nil

    static let tickSize: CGFloat = 14

    var body: some View {
        switch status {
        case .sending:
            Circle()
                .stroke(SplickTheme.Colors.textTertiary, lineWidth: 1.5)
                .frame(width: Self.tickSize, height: Self.tickSize)

        case .sent:
            ZStack {
                Circle()
                    .stroke(SplickTheme.Colors.primaryGradientStart, lineWidth: 1.5)
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
            .frame(width: Self.tickSize, height: Self.tickSize)

        case .delivered:
            ZStack {
                Circle()
                    .fill(SplickTheme.Colors.primaryGradientStart)
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.background)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: Self.tickSize, height: Self.tickSize)

        case .read:
            if showsReadAvatar {
                readAvatar
            } else {
                Color.clear
                    .frame(width: Self.tickSize, height: Self.tickSize)
            }

        case .failed:
            EmptyView()
        }
    }

    @ViewBuilder
    private var readAvatar: some View {
        let avatar = readAvatarContent
            .frame(width: Self.tickSize, height: Self.tickSize)
            .clipShape(Circle())

        if let readAvatarNamespace, let conversationId {
            avatar
                .matchedGeometryEffect(
                    id: "readReceiptAvatar-\(conversationId.uuidString)",
                    in: readAvatarNamespace
                )
        } else {
            avatar
        }
    }

    @ViewBuilder
    private var readAvatarContent: some View {
        if let readAvatarURL {
            AsyncImage(url: readAvatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    readAvatarPlaceholder
                }
            }
        } else {
            readAvatarPlaceholder
        }
    }

    private var readAvatarPlaceholder: some View {
        Circle()
            .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.35))
            .overlay {
                Text(initials)
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
    }

    private var initials: String {
        let parts = readAvatarName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
        let value = parts.joined().uppercased()
        return value.isEmpty ? "?" : value
    }
}
