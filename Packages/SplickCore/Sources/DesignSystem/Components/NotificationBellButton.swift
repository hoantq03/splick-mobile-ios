import SwiftUI

/// Toolbar bell that reports its global frame when tapped (for circular reveal transitions).
public struct NotificationBellButton: View {
    let unreadCount: Int
    let isPresented: Bool
    let accessibilityLabel: String
    let onTap: (CGRect) -> Void

    @State private var bellFrame: CGRect = .zero
    @State private var bellScale: CGFloat = 1
    @State private var bellOpacity: Double = 1

    private static let reappearSpring = Animation.spring(response: 0.22, dampingFraction: 0.72)
    private static let badgeHeight: CGFloat = 20
    private static let badgeMinWidth: CGFloat = 20

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
                Image(systemName: unreadCount > 0 ? "bell.fill" : "bell")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .frame(width: 34, height: 34)

                if unreadCount > 0, !isPresented {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.system(size: unreadCount > 99 ? 8 : 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, unreadCount > 9 ? 5.5 : 3.5)
                        .padding(.vertical, 1)
                        .frame(
                            minWidth: unreadCount > 9 ? Self.badgeMinWidth + 2 : Self.badgeMinWidth,
                            minHeight: Self.badgeHeight
                        )
                        .background {
                            Capsule(style: .continuous)
                                .fill(SplickTheme.Colors.error)
                                .overlay {
                                    Capsule(style: .continuous)
                                        .strokeBorder(.white.opacity(0.95), lineWidth: 1.5)
                                }
                                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                        }
                        .offset(x: 8, y: -5)
                }
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .background {
            SplickGlobalFrameReader(frame: $bellFrame)
        }
        .scaleEffect(bellScale)
        .opacity(bellOpacity)
        .allowsHitTesting(!isPresented)
        .accessibilityLabel(accessibilityLabel)
        .onChange(of: isPresented) { presented in
            if presented {
                withAnimation(SplickRevealMotion.expand) {
                    bellScale = 0.2
                    bellOpacity = 0
                }
            } else {
                withAnimation(Self.reappearSpring) {
                    bellScale = 1
                    bellOpacity = 1
                }
            }
        }
    }
}
