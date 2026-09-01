import SwiftUI
import DesignSystem

enum TypingAvatarAnchorSlot: String {
    case message
    case typing
}

struct TypingAvatarAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [TypingAvatarAnchorSlot: CGPoint] = [:]

    static func reduce(
        value: inout [TypingAvatarAnchorSlot: CGPoint],
        nextValue: () -> [TypingAvatarAnchorSlot: CGPoint]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    func reportTypingAvatarAnchor(
        slot: TypingAvatarAnchorSlot,
        isEnabled: Bool
    ) -> some View {
        background {
            if isEnabled {
                GeometryReader { geometry in
                    let frame = geometry.frame(in: .named("chatContent"))
                    Color.clear.preference(
                        key: TypingAvatarAnchorPreferenceKey.self,
                        value: [slot: CGPoint(x: frame.midX, y: frame.midY)]
                    )
                }
            }
        }
    }
}

struct TypingAvatarHandoffOverlay: View {
    var avatarURL: URL?
    var avatarName: String
    var userId: UUID?
    var messageCenter: CGPoint?
    var typingCenter: CGPoint?
    var progress: CGFloat

    var body: some View {
        if let messageCenter {
            let destination = typingCenter ?? messageCenter
            let centerX = messageCenter.x + (destination.x - messageCenter.x) * progress
            let centerY = messageCenter.y + (destination.y - messageCenter.y) * progress
            let name = avatarName.isEmpty ? "?" : avatarName

            AvatarView(
                imageURL: avatarURL,
                name: name,
                size: .small,
                userId: userId
            )
            .position(x: centerX, y: centerY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
