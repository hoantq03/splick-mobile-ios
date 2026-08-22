import SwiftUI
import DesignSystem
import SplickDomain

struct MessageStatusIndicator: View {
    let status: MessageDeliveryStatus
    var showsReadAvatar: Bool = false
    var readAvatarURL: URL? = nil
    var readAvatarName: String = ""

    static let tickSize: CGFloat = 18

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
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
            .frame(width: Self.tickSize, height: Self.tickSize)

        case .delivered:
            ZStack {
                Circle()
                    .fill(SplickTheme.Colors.primaryGradientStart)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.background)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: Self.tickSize, height: Self.tickSize)

        case .read:
            if showsReadAvatar {
                readAvatar
                    .frame(width: Self.tickSize, height: Self.tickSize)
                    .clipShape(Circle())
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
        readAvatarContent
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
                    .font(.system(size: 8, weight: .bold))
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
