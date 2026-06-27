import SwiftUI

/// Toolbar bell that reports its global frame when tapped (for circular reveal transitions).
public struct NotificationBellButton: View {
    let unreadCount: Int
    let isPresented: Bool
    let accessibilityLabel: String
    let onTap: (CGRect) -> Void

    @State private var bellFrame: CGRect = .zero

    public init(
        unreadCount: Int,
        isPresented: Bool = false,
        accessibilityLabel: String,
        onTap: @escaping (CGRect) -> Void
    ) {
        self.unreadCount = unreadCount
        self.isPresented = isPresented
        self.accessibilityLabel = accessibilityLabel
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            DispatchQueue.main.async {
                let frame = bellFrame
                guard frame.width > 1, frame.height > 1 else { return }
                onTap(frame)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .frame(width: 34, height: 34)

                if unreadCount > 0, !isPresented {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(SplickTheme.Colors.error))
                        .offset(x: 6, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
        .background {
            SplickGlobalFrameReader(frame: $bellFrame)
        }
        .scaleEffect(isPresented ? 0.2 : 1)
        .opacity(isPresented ? 0 : 1)
        .allowsHitTesting(!isPresented)
        .accessibilityLabel(accessibilityLabel)
        .animation(SplickRevealMotion.expand, value: isPresented)
    }
}
