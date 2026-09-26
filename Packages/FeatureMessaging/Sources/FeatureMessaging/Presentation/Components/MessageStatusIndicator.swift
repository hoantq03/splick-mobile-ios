import SwiftUI
import DesignSystem
import SplickDomain

struct ChatReadReceiptAnchor {
    let messageId: UUID
    let bounds: Anchor<CGRect>
}

enum ChatReadReceiptAnchorKey: PreferenceKey {
    static var defaultValue: ChatReadReceiptAnchor? { nil }

    static func reduce(value: inout ChatReadReceiptAnchor?, nextValue: () -> ChatReadReceiptAnchor?) {
        value = nextValue() ?? value
    }
}

struct MessageReadReceiptAvatar: View {
    let url: URL?
    let name: String

    var body: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.35))
            .overlay {
                Text(initials)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
    }

    private var initials: String {
        let parts = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
        let value = parts.joined().uppercased()
        return value.isEmpty ? "?" : value
    }
}

/// Single floating avatar so a new read receipt slides instead of fading out/in.
struct ChatReadReceiptAvatarOverlay: View {
    let anchor: ChatReadReceiptAnchor?
    let avatarURL: URL?
    let avatarName: String
    let isVisible: Bool

    var body: some View {
        GeometryReader { geometry in
            if isVisible, let anchor {
                let frame = geometry[anchor.bounds]
                MessageReadReceiptAvatar(url: avatarURL, name: avatarName)
                    .frame(width: MessageStatusIndicator.tickSize, height: MessageStatusIndicator.tickSize)
                    .clipShape(Circle())
                    .position(x: frame.midX, y: frame.midY)
                    .transition(.identity)
            }
        }
        .animation(ChatScrollAnimation.spring, value: anchor?.messageId)
        .allowsHitTesting(false)
        .clipped()
    }
}

struct MessageStatusIndicator: View {
    let status: MessageDeliveryStatus
    var showsReadAvatar: Bool = false
    var readAvatarURL: URL? = nil
    var readAvatarName: String = ""
    var readReceiptMessageId: UUID? = nil

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
            Color.clear
                .frame(width: Self.tickSize, height: Self.tickSize)
                .anchorPreference(key: ChatReadReceiptAnchorKey.self, value: .bounds) { bounds in
                    guard showsReadAvatar, let readReceiptMessageId else { return nil }
                    return ChatReadReceiptAnchor(messageId: readReceiptMessageId, bounds: bounds)
                }

        case .failed:
            EmptyView()
        }
    }
}
